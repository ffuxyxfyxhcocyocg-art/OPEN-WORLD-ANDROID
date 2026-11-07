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
    private static final float MOVE_SPEED = 4.5f;
    private int program, posLoc, mvpLoc, colorLoc;
    private FloatBuffer cube;
    private final float[] projection=new float[16], view=new float[16], model=new float[16], vp=new float[16], mvp=new float[16];
    private volatile float moveX, moveY, yaw;
    private volatile int gridRadius = 5;
    private volatile float blockSpacing = 8f, roadWidth = 9f, buildingMinHeight = 3.5f, buildingHeightStep = 1.2f;
    private volatile float cameraDistance = 10f, cameraHeight = 7.2f;
    private float playerX, playerZ;
    private long lastFrameNanos;

    public void setMovement(float x,float y){ moveX=Math.max(-1,Math.min(1,x)); moveY=Math.max(-1,Math.min(1,y)); }
    public void rotateCamera(float dx,float dy){ yaw += dx*0.004f; }

    public void setWorldConfig(JSONObject world) {
        if (world == null) return;
        JSONObject s = world.optJSONObject("world_settings");
        if (s == null) return;
        gridRadius = clamp(s.optInt("grid_radius", 5), 2, 10);
        blockSpacing = clamp(s.optDouble("block_spacing", 8.0), 5f, 20f);
        roadWidth = clamp(s.optDouble("road_width", 9.0), 5f, 16f);
        buildingMinHeight = clamp(s.optDouble("building_min_height", 3.5), 2f, 12f);
        buildingHeightStep = clamp(s.optDouble("building_height_step", 1.2), 0.3f, 4f);
        cameraDistance = clamp(s.optDouble("camera_distance", 10.0), 5f, 18f);
        cameraHeight = clamp(s.optDouble("camera_height", 7.2), 3f, 14f);
    }
    private float clamp(double v, float min, float max) { return (float)Math.max(min, Math.min(max, v)); }
    private int clamp(int v, int min, int max) { return Math.max(min, Math.min(max, v)); }

    @Override public void onSurfaceCreated(GL10 gl,EGLConfig config){
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
        lastFrameNanos = System.nanoTime();
    }

    @Override public void onSurfaceChanged(GL10 gl,int width,int height){
        GLES20.glViewport(0,0,width,height);
        Matrix.perspectiveM(projection,0,65f,(float)width/Math.max(1,height),0.1f,220f);
    }

    @Override public void onDrawFrame(GL10 gl){
        long now = System.nanoTime();
        float delta = Math.min(0.05f, Math.max(0f, (now - lastFrameNanos) / 1_000_000_000f));
        lastFrameNanos = now;

        float forward = moveY * MOVE_SPEED * delta;
        float strafe = moveX * MOVE_SPEED * delta;
        float sin = (float)Math.sin(yaw);
        float cos = (float)Math.cos(yaw);
        playerX += strafe * cos - forward * sin;
        playerZ -= strafe * sin + forward * cos;

        float cx=playerX+sin*cameraDistance;
        float cz=playerZ+cos*cameraDistance;
        Matrix.setLookAtM(view,0,cx,cameraHeight,cz,playerX,0.8f,playerZ,0,1,0);
        Matrix.multiplyMM(vp,0,projection,0,view,0);
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT|GLES20.GL_DEPTH_BUFFER_BIT);
        GLES20.glUseProgram(program);
        float span = (gridRadius * 2 + 2) * blockSpacing;
        box(0,-0.3f,0,span,0.5f,span,0.23f,0.43f,0.25f);
        box(0,-0.02f,0,roadWidth,0.08f,span,0.16f,0.17f,0.19f);
        box(0,-0.01f,0,span,0.08f,roadWidth,0.16f,0.17f,0.19f);
        for(int i=-gridRadius;i<=gridRadius;i++){
            box(i*blockSpacing,0.03f,0,0.10f,0.02f,span,0.92f,0.82f,0.48f);
            box(0,0.03f,i*blockSpacing,span,0.02f,0.10f,0.92f,0.82f,0.48f);
        }
        for(int x=-gridRadius;x<=gridRadius;x++) for(int z=-gridRadius;z<=gridRadius;z++){
            if(x==0||z==0) continue;
            float h=buildingMinHeight+((x*x+z*z)%5)*buildingHeightStep;
            float shade=0.40f+((x-z+12)%4)*0.045f;
            box(x*blockSpacing,h/2f,z*blockSpacing,blockSpacing*0.575f,h,blockSpacing*0.575f,shade,shade*0.94f,shade*0.84f);
            box(x*blockSpacing,h+0.12f,z*blockSpacing,blockSpacing*0.60f,0.24f,blockSpacing*0.60f,0.18f,0.20f,0.23f);
        }
        box(playerX,0.95f,playerZ,0.62f,1.5f,0.42f,0.10f,0.24f,0.82f);
        box(playerX,1.90f,playerZ,0.46f,0.46f,0.46f,0.78f,0.57f,0.42f);
        for(int i=-2;i<=2;i++){
            float x=i*13f+5f,z=-12f;
            box(x,0.48f,z,2.2f,0.72f,4.1f,0.72f,0.12f,0.10f);
            box(x,0.98f,z,1.7f,0.48f,1.8f,0.12f,0.25f,0.34f);
        }
    }

    private void box(float x,float y,float z,float sx,float sy,float sz,float r,float g,float b){
        Matrix.setIdentityM(model,0);
        Matrix.translateM(model,0,x,y,z);
        Matrix.scaleM(model,0,sx,sy,sz);
        Matrix.multiplyMM(mvp,0,vp,0,model,0);
        GLES20.glUniformMatrix4fv(mvpLoc,1,false,mvp,0);
        GLES20.glUniform4f(colorLoc,r,g,b,1f);
        cube.position(0);
        GLES20.glEnableVertexAttribArray(posLoc);
        GLES20.glVertexAttribPointer(posLoc,3,GLES20.GL_FLOAT,false,0,cube);
        GLES20.glDrawArrays(GLES20.GL_TRIANGLES,0,36);
    }

    private int link(String vertex,String fragment){
        int vs=compile(GLES20.GL_VERTEX_SHADER,vertex), fs=compile(GLES20.GL_FRAGMENT_SHADER,fragment);
        int p=GLES20.glCreateProgram(); GLES20.glAttachShader(p,vs); GLES20.glAttachShader(p,fs); GLES20.glLinkProgram(p);
        int[] ok=new int[1]; GLES20.glGetProgramiv(p,GLES20.GL_LINK_STATUS,ok,0);
        if(ok[0]==0) throw new RuntimeException("OpenGL link failed: "+GLES20.glGetProgramInfoLog(p));
        return p;
    }
    private int compile(int type,String source){
        int s=GLES20.glCreateShader(type); GLES20.glShaderSource(s,source); GLES20.glCompileShader(s);
        int[] ok=new int[1]; GLES20.glGetShaderiv(s,GLES20.GL_COMPILE_STATUS,ok,0);
        if(ok[0]==0) throw new RuntimeException("OpenGL shader failed: "+GLES20.glGetShaderInfoLog(s));
        return s;
    }
}
