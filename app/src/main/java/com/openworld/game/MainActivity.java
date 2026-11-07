package com.openworld.game;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.opengl.GLSurfaceView;
import android.graphics.Color;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;

public class MainActivity extends Activity {
    private static final long UPDATE_INTERVAL_MS=30_000L;
    private final Handler updateHandler=new Handler(Looper.getMainLooper());
    private boolean updateLoopActive=false;
    private GLSurfaceView surface;
    private GameRenderer renderer;
    private TextView status,vehicleButton;
    private int movePointerId=-1,lookPointerId=-1;
    private float moveStartX,moveStartY,lastLookX,lastLookY;
    private final Runnable updateLoop=new Runnable(){
        @Override public void run(){
            if(!updateLoopActive||isFinishing())return;
            checkRemoteContent();updateHandler.postDelayed(this,UPDATE_INTERVAL_MS);
        }
    };

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_FULLSCREEN|View.SYSTEM_UI_FLAG_HIDE_NAVIGATION|
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY|View.SYSTEM_UI_FLAG_LAYOUT_STABLE|
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        );
        FrameLayout root=new FrameLayout(this);
        surface=new GLSurfaceView(this);surface.setEGLContextClientVersion(2);
        renderer=new GameRenderer();surface.setRenderer(renderer);
        surface.setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);
        surface.setOnTouchListener((v,e)->{
            int action=e.getActionMasked(),index=e.getActionIndex();
            if(action==MotionEvent.ACTION_DOWN||action==MotionEvent.ACTION_POINTER_DOWN){
                int id=e.getPointerId(index);float x=e.getX(index),y=e.getY(index);
                if(x<v.getWidth()*0.48f&&movePointerId==-1){
                    movePointerId=id;moveStartX=x;moveStartY=y;renderer.setMovement(0f,0f);
                }else if(x>=v.getWidth()*0.48f&&lookPointerId==-1){
                    lookPointerId=id;lastLookX=x;lastLookY=y;
                }
                return true;
            }
            if(action==MotionEvent.ACTION_MOVE){
                for(int i=0;i<e.getPointerCount();i++){
                    int id=e.getPointerId(i);float x=e.getX(i),y=e.getY(i);
                    if(id==movePointerId){
                        float rx=Math.max(1f,v.getWidth()*0.13f),ry=Math.max(1f,v.getHeight()*0.18f);
                        renderer.setMovement(clamp((x-moveStartX)/rx),clamp((moveStartY-y)/ry));
                    }else if(id==lookPointerId){
                        renderer.rotateCamera(lastLookX-x,lastLookY-y);lastLookX=x;lastLookY=y;
                    }
                }
                return true;
            }
            if(action==MotionEvent.ACTION_POINTER_UP||action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_CANCEL){
                if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_CANCEL){
                    movePointerId=-1;lookPointerId=-1;renderer.setMovement(0f,0f);
                }else{
                    int lifted=e.getPointerId(index);
                    if(lifted==movePointerId){movePointerId=-1;renderer.setMovement(0f,0f);}
                    if(lifted==lookPointerId)lookPointerId=-1;
                }
                return true;
            }
            return true;
        });
        root.addView(surface);

        TextView title=makeLabel("OPEN WORLD  •  ANDROID DEV",12,0xCC101820);
        FrameLayout.LayoutParams top=new FrameLayout.LayoutParams(-2,-2,Gravity.TOP|Gravity.CENTER_HORIZONTAL);
        top.topMargin=dp(12);root.addView(title,top);
        status=makeLabel("Carregando mundo...",10,0x99101820);
        FrameLayout.LayoutParams bottom=new FrameLayout.LayoutParams(-2,-2,Gravity.BOTTOM|Gravity.CENTER_HORIZONTAL);
        bottom.bottomMargin=dp(10);root.addView(status,bottom);

        TextView jumpButton=makeButton("PULAR");
        FrameLayout.LayoutParams jumpParams=new FrameLayout.LayoutParams(dp(82),dp(54),Gravity.RIGHT|Gravity.BOTTOM);
        jumpParams.rightMargin=dp(22);jumpParams.bottomMargin=dp(92);root.addView(jumpButton,jumpParams);
        jumpButton.setOnClickListener(view->renderer.jump());

        vehicleButton=makeButton("ENTRAR");
        FrameLayout.LayoutParams carParams=new FrameLayout.LayoutParams(dp(100),dp(54),Gravity.RIGHT|Gravity.BOTTOM);
        carParams.rightMargin=dp(22);carParams.bottomMargin=dp(28);root.addView(vehicleButton,carParams);
        vehicleButton.setOnClickListener(view->{
            renderer.enterExitVehicle();
            vehicleButton.setText(renderer.isDriving()?"SAIR DO CARRO":"ENTRAR");
        });

        TextView hint=makeLabel("ESQUERDA: MOVER     DIREITA: CÂMERA",9,0x88101820);
        FrameLayout.LayoutParams hintParams=new FrameLayout.LayoutParams(-2,-2,Gravity.LEFT|Gravity.BOTTOM);
        hintParams.leftMargin=dp(14);hintParams.bottomMargin=dp(12);root.addView(hint,hintParams);
        setContentView(root);
    }

    private TextView makeLabel(String text,int size,int background){
        TextView v=new TextView(this);v.setText(text);v.setTextColor(Color.WHITE);v.setTextSize(size);
        v.setPadding(dp(12),dp(8),dp(12),dp(8));v.setBackgroundColor(background);return v;
    }
    private TextView makeButton(String text){
        TextView v=makeLabel(text,12,0xDD182534);v.setGravity(Gravity.CENTER);v.setTextColor(Color.WHITE);
        v.setElevation(dp(5));return v;
    }
    private int dp(float value){return(int)(value*getResources().getDisplayMetrics().density+0.5f);}
    private void checkRemoteContent(){
        if(status!=null)status.setText("Verificando atualizações...");
        ContentUpdater.check(this,(message,world)->runOnUiThread(()->{
            if(isFinishing()||surface==null||renderer==null)return;
            status.setText(message);
            if(world!=null)surface.queueEvent(()->renderer.setWorldConfig(world));
        }));
    }
    private static float clamp(float value){return Math.max(-1f,Math.min(1f,value));}
    @Override protected void onPause(){
        updateLoopActive=false;updateHandler.removeCallbacks(updateLoop);
        movePointerId=-1;lookPointerId=-1;
        if(surface!=null)surface.onPause();if(renderer!=null)renderer.setMovement(0f,0f);
        super.onPause();
    }
    @Override protected void onResume(){
        super.onResume();if(surface!=null)surface.onResume();
        updateLoopActive=true;updateHandler.removeCallbacks(updateLoop);
        checkRemoteContent();updateHandler.postDelayed(updateLoop,UPDATE_INTERVAL_MS);
    }
    @Override protected void onDestroy(){
        updateLoopActive=false;updateHandler.removeCallbacks(updateLoop);super.onDestroy();
    }
}