package com.openworld.game;

import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.opengl.Matrix;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class GameRenderer implements GLSurfaceView.Renderer {
    private static final String VERT = "attribute vec3 aPos; uniform mat4 uMvp; void main(){ gl_Position=uMvp*vec4(aPos,1.0); }";
    private static final String FRAG = "precision mediump float; uniform vec4 uColor; void main(){ gl_FragColor=uColor; }";
    private int program, posLoc, mvpLoc, colorLoc;
    private FloatBuffer cube;
    private final float[] projection=new float[16], view=new float[16], model=new float[16], vp=new float[16], mvp=new float[16];
    private volatile float moveX, moveY, yaw;
    private float playerX, playerZ;

    public void setMovement(float x,float y){ moveX=Math.max(-1,Math.min(1,x)); moveY=Math.max(-1,Math.min(1,y)); }
    public void rotateCamera(float dx,float dy){ yaw += dx*0.004f; }

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
    }

    @Override public void onSurfaceChanged(GL10 gl,int width,int height){
        GLES20.glViewport(0,0,width,height);
        Matrix.perspectiveM(projection,0,65f,(float)width/Math.max(1,height),0.1f,220f);
    }

    @Override public void onDrawFrame(GL10 gl){
        playerX += moveX*0.075f;
        playerZ -= moveY*0.075f;
        float cx=playerX+(float)Math.sin(yaw)*10f;
        float cz=playerZ+(float)Math.cos(yaw)*10f;
        Matrix.setLookAtM(view,0,cx,7.2f,cz,playerX,0.8f,playerZ,0,1,0);
        Matrix.multiplyMM(vp,0,projection,0,view,0);
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT|GLES20.GL_DEPTH_BUFFER_BIT);
        GLES20.glUseProgram(program);
        box(0,-0.3f,0,100,0.5f,100,0.23f,0.43f,0.25f);
        box(0,-0.02f,0,9,0.08f,100,0.16f,0.17f,0.19f);
        box(0,-0.01f,0,100,0.08f,9,0.16f,0.17f,0.19f);
        for(int i=-6;i<=6;i++){
            box(i*8f,0.03f,0,0.10f,0.02f,100,0.92f,0.82f,0.48f);
            box(0,0.03f,i*8f,100,0.02f,0.10f,0.92f,0.82f,0.48f);
        }
        for(int x=-5;x<=5;x++) for(int z=-5;z<=5;z++){
            if(x==0||z==0) continue;
            float h=3.5f+((x*x+z*z)%5)*1.2f;
            float shade=0.40f+((x-z+12)%4)*0.045f;
            box(x*8f,h/2f,z*8f,4.6f,h,4.6f,shade,shade*0.94f,shade*0.84f);
            box(x*8f,h+0.12f,z*8f,4.8f,0.24f,4.8f,0.18f,0.20f,0.23f);
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
