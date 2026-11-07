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
    private int activePointerId = -1;
    private float lastTouchX, lastTouchY;

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

            if (action == MotionEvent.ACTION_DOWN) {
                activePointerId = e.getPointerId(0);
                lastTouchX = e.getX(0);
                lastTouchY = e.getY(0);
                if (lastTouchX / Math.max(1f, v.getWidth()) < 0.48f) {
                    updateTouchControl(v.getWidth(), v.getHeight(), lastTouchX, lastTouchY);
                } else {
                    renderer.setMovement(0f, 0f);
                }
                return true;
            }

            if (action == MotionEvent.ACTION_MOVE && activePointerId != -1) {
                int index = e.findPointerIndex(activePointerId);
                if (index >= 0) {
                    float x = e.getX(index);
                    float y = e.getY(index);
                    boolean onLeft = x / Math.max(1f, v.getWidth()) < 0.48f;
                    if (onLeft) {
                        updateTouchControl(v.getWidth(), v.getHeight(), x, y);
                    } else {
                        renderer.setMovement(0f, 0f);
                        renderer.rotateCamera(lastTouchX - x, lastTouchY - y);
                    }
                    lastTouchX = x;
                    lastTouchY = y;
                }
                return true;
            }

            if (action == MotionEvent.ACTION_UP ||
                action == MotionEvent.ACTION_CANCEL ||
                action == MotionEvent.ACTION_POINTER_UP) {
                if (action != MotionEvent.ACTION_POINTER_UP ||
                    e.getPointerId(e.getActionIndex()) == activePointerId) {
                    activePointerId = -1;
                    renderer.setMovement(0f, 0f);
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

    private void updateTouchControl(int width, int height, float x, float y) {
        float nx = x / Math.max(1f, width);
        float ny = y / Math.max(1f, height);
        renderer.setMovement((nx - 0.20f) * 5.0f, (0.78f - ny) * 5.0f);
    }

    @Override protected void onPause() {
        super.onPause();
        if (surface != null) surface.onPause();
        if (renderer != null) renderer.setMovement(0f, 0f);
    }

    @Override protected void onResume() {
        super.onResume();
        if (surface != null) surface.onResume();
    }
}
