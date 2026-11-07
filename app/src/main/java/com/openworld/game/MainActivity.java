package com.openworld.game;

import android.app.Activity;
import android.os.Bundle;
import android.opengl.GLSurfaceView;
import android.graphics.Color;
import android.view.Gravity;
import android.view.MotionEvent;
import android.widget.FrameLayout;
import android.widget.TextView;

public class MainActivity extends Activity {
    private GLSurfaceView surface;
    private GameRenderer renderer;
    private TextView status;
    private int movePointerId = -1;
    private int lookPointerId = -1;
    private float moveStartX, moveStartY;
    private float lastLookX, lastLookY;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        FrameLayout root = new FrameLayout(this);
        surface = new GLSurfaceView(this);
        surface.setEGLContextClientVersion(2);
        renderer = new GameRenderer();
        surface.setRenderer(renderer);
        surface.setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);

        surface.setOnTouchListener((v, e) -> {
            int action = e.getActionMasked();
            int index = e.getActionIndex();

            if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
                int id = e.getPointerId(index);
                float x = e.getX(index);
                float y = e.getY(index);
                boolean leftSide = x < v.getWidth() * 0.48f;

                if (leftSide && movePointerId == -1) {
                    movePointerId = id;
                    moveStartX = x;
                    moveStartY = y;
                    renderer.setMovement(0f, 0f);
                } else if (!leftSide && lookPointerId == -1) {
                    lookPointerId = id;
                    lastLookX = x;
                    lastLookY = y;
                }
                return true;
            }

            if (action == MotionEvent.ACTION_MOVE) {
                for (int i = 0; i < e.getPointerCount(); i++) {
                    int id = e.getPointerId(i);
                    float x = e.getX(i);
                    float y = e.getY(i);

                    if (id == movePointerId) {
                        float rangeX = Math.max(1f, v.getWidth() * 0.13f);
                        float rangeY = Math.max(1f, v.getHeight() * 0.18f);
                        float mx = (x - moveStartX) / rangeX;
                        float my = (moveStartY - y) / rangeY;
                        renderer.setMovement(clamp(mx), clamp(my));
                    } else if (id == lookPointerId) {
                        renderer.rotateCamera(lastLookX - x, lastLookY - y);
                        lastLookX = x;
                        lastLookY = y;
                    }
                }
                return true;
            }

            if (action == MotionEvent.ACTION_POINTER_UP || action == MotionEvent.ACTION_UP ||
                action == MotionEvent.ACTION_CANCEL) {
                if (action == MotionEvent.ACTION_CANCEL || action == MotionEvent.ACTION_UP) {
                    movePointerId = -1;
                    lookPointerId = -1;
                    renderer.setMovement(0f, 0f);
                } else {
                    int liftedId = e.getPointerId(index);
                    if (liftedId == movePointerId) {
                        movePointerId = -1;
                        renderer.setMovement(0f, 0f);
                    }
                    if (liftedId == lookPointerId) lookPointerId = -1;
                }
                return true;
            }
            return true;
        });
        root.addView(surface);

        TextView title = new TextView(this);
        title.setText("OPEN WORLD  •  DEV BUILD 0.1");
        title.setTextColor(Color.WHITE);
        title.setTextSize(13);
        title.setPadding(18, 12, 18, 12);
        title.setBackgroundColor(0x990B1018);
        FrameLayout.LayoutParams top = new FrameLayout.LayoutParams(-2, -2, Gravity.TOP|Gravity.CENTER_HORIZONTAL);
        top.topMargin = 12;
        root.addView(title, top);

        status = new TextView(this);
        status.setText("Verificando conteúdo...");
        status.setTextColor(Color.WHITE);
        status.setTextSize(11);
        status.setPadding(12, 8, 12, 8);
        status.setBackgroundColor(0x880B1018);
        FrameLayout.LayoutParams bottom = new FrameLayout.LayoutParams(-2, -2, Gravity.BOTTOM|Gravity.CENTER_HORIZONTAL);
        bottom.bottomMargin = 10;
        root.addView(status, bottom);
        setContentView(root);

        ContentUpdater.check(this, (message, world) -> runOnUiThread(() -> {
            status.setText(message);
            surface.queueEvent(() -> renderer.setWorldConfig(world));
        }));
    }

    private static float clamp(float value) {
        return Math.max(-1f, Math.min(1f, value));
    }

    @Override protected void onPause() {
        super.onPause();
        movePointerId = -1;
        lookPointerId = -1;
        if (surface != null) surface.onPause();
        if (renderer != null) renderer.setMovement(0f, 0f);
    }

    @Override protected void onResume() {
        super.onResume();
        if (surface != null) surface.onResume();
    }
}
