package com.openworld.game;

import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.opengl.Matrix;
import org.json.JSONObject;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class GameRenderer implements GLSurfaceView.Renderer {
    private static final String VERT = "attribute vec3 aPos; uniform mat4 uMvp; void main(){ gl_Position=uMvp*vec4(aPos,1.0); }";
    private static final String FRAG = "precision mediump float; uniform vec4 uColor; void main(){ gl_FragColor=uColor; }";
    private static final float WALK_SPEED = 4.2f, RUN_SPEED = 6.6f;
    private int program, posLoc, mvpLoc, colorLoc;
    private FloatBuffer cube;
    private final float[] projection=new float[16], view=new float[16], model=new float[16], vp=new float[16], mvp=new float[16];
    private volatile float moveX, moveY, cameraYaw;
    private volatile int gridRadius=5;
    private volatile float blockSpacing=8f, roadWidth=9f, buildingMinHeight=3.5f, buildingHeightStep=1.2f;
    private float playerX, playerZ, playerHeading, walkPhase, jumpHeight;
    private long lastFrameNanos, jumpStartNanos;
    private boolean inVehicle;
    private float carX, carZ, carHeading;

    public void setMovement(float x,float y){ moveX=Math.max(-1,Math.min(1,x)); moveY=Math.max(-1,Math.min(1,y)); }
    public void rotateCamera(float dx,float dy){ cameraYaw += dx*0.004f; }

    public synchronized void enterExitVehicle() {
        if (inVehicle) {
            inVehicle=false;
            playerX=carX+(float)Math.cos(carHeading)*1.8f;
            playerZ=carZ+(float)Math.sin(carHeading)*1.8f;
            if(blocked(playerX,playerZ,0.45f)) {
                playerX=carX-(float)Math.cos(carHeading)*1.8f;
                playerZ=carZ-(float)Math.sin(carHeading)*1.8f;
            }
            playerHeading=carHeading;
        } else {
            float dx=playerX-carX, dz=playerZ-carZ;
            if(dx*dx+dz*dz<16f) {
                inVehicle=true; playerX=carX; playerZ=carZ;
                playerHeading=carHeading; cameraYaw=carHeading;
            }
        }
    }
    public synchronized void jump() {
        if(!inVehicle && jumpHeight<=0.01f) jumpStartNanos=System.nanoTime();
    }
    public synchronized boolean isDriving(){ return inVehicle; }

    public void setWorldConfig(JSONObject world) {
        if(world==null)return;
        JSONObject s=world.optJSONObject("world_settings");
        if(s==null)return;
        gridRadius=clamp(s.optInt("grid_radius",5),2,10);
        blockSpacing=clamp(s.optDouble("block_spacing",8.0),5f,20f);
        roadWidth=clamp(s.optDouble("road_width",9.0),5f,16f);
        buildingMinHeight=clamp(s.optDouble("building_min_height",3.5),2f,12f);
        buildingHeightStep=clamp(s.optDouble("building_height_step",1.2),0.3f,4f);
    }
    private float clamp(double v,float min,float max){return(float)Math.max(min,Math.min(max,v));}
    private int clamp(int v,int min,int max){return Math.max(min,Math.min(max,v));}

    @Override public void onSurfaceCreated(GL10 gl,EGLConfig config) {
        GLES20.glClearColor(0.48f,0.70f,0.88f,1f);
        GLES20.glEnable(GLES20.GL_DEPTH_TEST);
        program=link(VERT,FRAG);
        posLoc=GLES20.glGetAttribLocation(program,"aPos");
        mvpLoc=GLES20.glGetUniformLocation(program,"uMvp");
        colorLoc=GLES20.glGetUniformLocation(program,"uColor");
        float[] v={
          -.5f,-.5f,.5f, .5f,-.5f,.5f, .5f,.5f,.5f, -.5f,-.5f,.5f, .5f,.5f,.5f, -.5f,.5f,.5f,
          .5f,-.5f,-.5f, -.5f,-.5f,-.5f, -.5f,.5f,-.5f, .5f,-.5f,-.5f, -.5f,.5f,-.5f, .5f,.5f,-.5f,
          -.5f,-.5f,-.5f, -.5f,-.5f,.5f, -.5f,.5f,.5f, -.5f,-.5f,-.5f, -.5f,.5f,.5f, -.5f,.5f,-.5f,
          .5f,-.5f,.5f, .5f,-.5f,-.5f, .5f,.5f,-.5f, .5f,-.5f,.5f, .5f,.5f,-.5f, .5f,.5f,.5f,
          -.5f,.5f,.5f, .5f,.5f,.5f, .5f,.5f,-.5f, -.5f,.5f,.5f, .5f,.5f,-.5f, -.5f,.5f,-.5f,
          -.5f,-.5f,-.5f, .5f,-.5f,-.5f, .5f,-.5f,.5f, -.5f,-.5f,-.5f, .5f,-.5f,.5f, -.5f,-.5f,.5f
        };
        cube=ByteBuffer.allocateDirect(v.length*4).order(ByteOrder.nativeOrder()).asFloatBuffer();
        cube.put(v).position(0);
        lastFrameNanos=System.nanoTime();
        carX=0f; carZ=-5.8f; carHeading=0f;
    }
    @Override public void onSurfaceChanged(GL10 gl,int width,int height) {
        GLES20.glViewport(0,0,width,height);
        Matrix.perspectiveM(projection,0,65f,(float)width/Math.max(1,height),0.1f,260f);
    }

    @Override public void onDrawFrame(GL10 gl) {
        long now=System.nanoTime();
        float delta=Math.min(0.05f,Math.max(0f,(now-lastFrameNanos)/1_000_000_000f));
        lastFrameNanos=now;
        float inputLen=(float)Math.sqrt(moveX*moveX+moveY*moveY);
        if(inVehicle) {
            if(Math.abs(moveY)>0.03f) {
                carHeading+=moveX*delta*1.65f*Math.signum(moveY);
                float speed=10.5f*moveY;
                float nx=carX-(float)Math.sin(carHeading)*speed*delta;
                float nz=carZ-(float)Math.cos(carHeading)*speed*delta;
                if(!blocked(nx,nz,1.25f)){carX=nx;carZ=nz;}
            }
            playerX=carX;playerZ=carZ;playerHeading=carHeading;cameraYaw=carHeading;
        } else if(inputLen>0.04f) {
            float sin=(float)Math.sin(cameraYaw),cos=(float)Math.cos(cameraYaw);
            float speed=inputLen>0.88f?RUN_SPEED:WALK_SPEED;
            float dx=(moveX*cos-moveY*sin)*speed*delta;
            float dz=(-moveX*sin-moveY*cos)*speed*delta;
            if(!blocked(playerX+dx,playerZ,0.42f))playerX+=dx;
            if(!blocked(playerX,playerZ+dz,0.42f))playerZ+=dz;
            playerHeading=(float)Math.atan2(-dx,-dz);
            walkPhase+=delta*(inputLen>0.88f?13f:8f);
        }
        if(!inVehicle&&jumpStartNanos>0) {
            float t=(now-jumpStartNanos)/1_000_000_000f;
            if(t>=0.72f){jumpStartNanos=0;jumpHeight=0;}
            else jumpHeight=(float)(Math.sin((t/0.72f)*Math.PI)*1.05f);
        } else jumpHeight=0;

        float cs=(float)Math.sin(cameraYaw),cc=(float)Math.cos(cameraYaw);
        float distance=inVehicle?12f:9.5f, height=inVehicle?6f:5.5f;
        Matrix.setLookAtM(view,0,playerX+cs*distance,height,playerZ+cc*distance,playerX,1f,playerZ,0,1,0);
        Matrix.multiplyMM(vp,0,projection,0,view,0);
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT|GLES20.GL_DEPTH_BUFFER_BIT);
        GLES20.glUseProgram(program);

        float span=(gridRadius*2+2)*blockSpacing;
        box(0,-0.3f,0,span,0.5f,span,0.23f,0.43f,0.25f);
        box(0,-0.02f,0,roadWidth,0.08f,span,0.16f,0.17f,0.19f);
        box(0,-0.01f,0,span,0.08f,roadWidth,0.16f,0.17f,0.19f);
        for(int i=-gridRadius;i<=gridRadius;i++){
            box(i*blockSpacing,0.03f,0,0.10f,0.02f,span,0.92f,0.82f,0.48f);
            box(0,0.03f,i*blockSpacing,span,0.02f,0.10f,0.92f,0.82f,0.48f);
        }
        for(int x=-gridRadius;x<=gridRadius;x++)for(int z=-gridRadius;z<=gridRadius;z++){
            if(x==0||z==0)continue;
            float h=buildingMinHeight+((x*x+z*z)%5)*buildingHeightStep;
            float shade=0.40f+((x-z+12)%4)*0.045f;
            float bx=x*blockSpacing,bz=z*blockSpacing;
            box(bx,h/2f,bz,blockSpacing*0.575f,h,blockSpacing*0.575f,shade,shade*0.94f,shade*0.84f);
            box(bx,h+0.12f,bz,blockSpacing*0.60f,0.24f,blockSpacing*0.60f,0.18f,0.20f,0.23f);
            for(int w=-1;w<=1;w++)
                box(bx+w*1.15f,Math.min(h-0.6f,2f),bz+blockSpacing*0.291f,0.72f,0.78f,0.035f,0.12f,0.28f,0.38f);
        }
        drawCar(carX,carZ,carHeading);
        if(!inVehicle)drawPlayer();
        else {
            boxRot(carX,1.05f,carZ,0.34f,0.72f,0.32f,0.10f,0.24f,0.82f,0,carHeading,0);
            boxRot(carX,1.48f,carZ,0.30f,0.30f,0.30f,0.78f,0.57f,0.42f,0,carHeading,0);
        }
    }

    private boolean blocked(float x,float z,float radius) {
        float limit=(gridRadius+1.2f)*blockSpacing;
        if(Math.abs(x)>limit||Math.abs(z)>limit)return true;
        for(int bx=-gridRadius;bx<=gridRadius;bx++)for(int bz=-gridRadius;bz<=gridRadius;bz++){
            if(bx==0||bz==0)continue;
            float cx=bx*blockSpacing,cz=bz*blockSpacing,half=blockSpacing*0.2875f;
            if(Math.abs(x-cx)<half+radius&&Math.abs(z-cz)<half+radius)return true;
        }
        return false;
    }
    private void drawPlayer() {
        float swing=(Math.abs(moveX)+Math.abs(moveY)>0.08f)?(float)Math.sin(walkPhase)*0.48f:0f;
        float y=jumpHeight;
        boxRot(playerX,1.08f+y,playerZ,0.58f,0.78f,0.34f,0.10f,0.27f,0.78f,0,playerHeading,0);
        boxRot(playerX,1.66f+y,playerZ,0.42f,0.42f,0.42f,0.78f,0.58f,0.43f,0,playerHeading,0);
        segment(playerX-0.39f,1.30f+y,playerZ,0.18f,0.56f,0.20f,0.08f,0.22f,0.66f,swing,playerHeading);
        segment(playerX+0.39f,1.30f+y,playerZ,0.18f,0.56f,0.20f,0.08f,0.22f,0.66f,-swing,playerHeading);
        segment(playerX-0.18f,0.62f+y,playerZ,0.22f,0.70f,0.24f,0.10f,0.12f,0.20f,-swing,playerHeading);
        segment(playerX+0.18f,0.62f+y,playerZ,0.22f,0.70f,0.24f,0.10f,0.12f,0.20f,swing,playerHeading);
    }
    private void segment(float x,float y,float z,float sx,float sy,float sz,float r,float g,float b,float swing,float heading) {
        Matrix.setIdentityM(model,0);Matrix.translateM(model,0,x,y,z);
        Matrix.rotateM(model,0,(float)Math.toDegrees(heading),0,1,0);
        Matrix.rotateM(model,0,(float)Math.toDegrees(swing),1,0,0);
        Matrix.translateM(model,0,0,-sy*0.5f,0);Matrix.scaleM(model,0,sx,sy,sz);drawModel(r,g,b);
    }
    private void drawCar(float x,float z,float heading) {
        boxRot(x,0.62f,z,2.05f,0.62f,3.7f,0.72f,0.12f,0.10f,0,heading,0);
        boxRot(x,1.08f,z,1.52f,0.70f,1.85f,0.10f,0.25f,0.36f,0,heading,0);
        for(int side=-1;side<=1;side+=2)for(int front=-1;front<=1;front+=2){
            float wx=x+(float)Math.cos(heading)*side+(float)Math.sin(heading)*front*1.25f;
            float wz=z+(float)Math.sin(heading)*side-(float)Math.cos(heading)*front*1.25f;
            boxRot(wx,0.34f,wz,0.38f,0.48f,0.72f,0.06f,0.06f,0.07f,0,heading,0);
        }
        boxRot(x,0.78f,z-(float)Math.cos(heading)*1.84f,0.48f,0.18f,0.10f,0.98f,0.88f,0.55f,0,heading,0);
    }
    private void box(float x,float y,float z,float sx,float sy,float sz,float r,float g,float b) {
        Matrix.setIdentityM(model,0);Matrix.translateM(model,0,x,y,z);Matrix.scaleM(model,0,sx,sy,sz);drawModel(r,g,b);
    }
    private void boxRot(float x,float y,float z,float sx,float sy,float sz,float r,float g,float b,float rx,float ry,float rz) {
        Matrix.setIdentityM(model,0);Matrix.translateM(model,0,x,y,z);
        Matrix.rotateM(model,0,(float)Math.toDegrees(ry),0,1,0);
        Matrix.rotateM(model,0,(float)Math.toDegrees(rx),1,0,0);
        Matrix.rotateM(model,0,(float)Math.toDegrees(rz),0,0,1);
        Matrix.scaleM(model,0,sx,sy,sz);drawModel(r,g,b);
    }
    private void drawModel(float r,float g,float b) {
        Matrix.multiplyMM(mvp,0,vp,0,model,0);
        GLES20.glUniformMatrix4fv(mvpLoc,1,false,mvp,0);GLES20.glUniform4f(colorLoc,r,g,b,1f);
        cube.position(0);GLES20.glEnableVertexAttribArray(posLoc);
        GLES20.glVertexAttribPointer(posLoc,3,GLES20.GL_FLOAT,false,0,cube);
        GLES20.glDrawArrays(GLES20.GL_TRIANGLES,0,36);
    }
    private int link(String vertex,String fragment) {
        int vs=compile(GLES20.GL_VERTEX_SHADER,vertex),fs=compile(GLES20.GL_FRAGMENT_SHADER,fragment);
        int p=GLES20.glCreateProgram();GLES20.glAttachShader(p,vs);GLES20.glAttachShader(p,fs);GLES20.glLinkProgram(p);
        int[] ok=new int[1];GLES20.glGetProgramiv(p,GLES20.GL_LINK_STATUS,ok,0);
        if(ok[0]==0)throw new RuntimeException("OpenGL link failed: "+GLES20.glGetProgramInfoLog(p));
        return p;
    }
    private int compile(int type,String source) {
        int s=GLES20.glCreateShader(type);GLES20.glShaderSource(s,source);GLES20.glCompileShader(s);
        int[] ok=new int[1];GLES20.glGetShaderiv(s,GLES20.GL_COMPILE_STATUS,ok,0);
        if(ok[0]==0)throw new RuntimeException("OpenGL shader failed: "+GLES20.glGetShaderInfoLog(s));
        return s;
    }
}