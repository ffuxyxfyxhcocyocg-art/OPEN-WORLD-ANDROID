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

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        FrameLayout root = new FrameLayout(this);
        surface = new GLSurfaceView(this);
        surface.setEGLContextClientVersion(2);
        renderer = new GameRenderer();
        surface.setRenderer(renderer);
        surface.setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);
        surface.setOnTouchListener((v, e) -> {
            float nx = e.getX() / Math.max(1f, v.getWidth());
            float ny = e.getY() / Math.max(1f, v.getHeight());
            if (nx < 0.48f) {
                if (e.getActionMasked() == MotionEvent.ACTION_MOVE ||
                    e.getActionMasked() == MotionEvent.ACTION_DOWN) {
                    renderer.setMovement((nx - 0.20f) * 5.0f, (0.78f - ny) * 5.0f);
                } else if (e.getActionMasked() == MotionEvent.ACTION_UP ||
                           e.getActionMasked() == MotionEvent.ACTION_CANCEL) {
                    renderer.setMovement(0f, 0f);
                }
            } else if (e.getActionMasked() == MotionEvent.ACTION_MOVE) {
                renderer.rotateCamera(e.getHistoricalX(0) - e.getX(),
                                      e.getHistoricalY(0) - e.getY());
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

        ContentUpdater.check(this, message -> runOnUiThread(() -> status.setText(message)));
    }

    @Override protected void onPause() { super.onPause(); if (surface != null) surface.onPause(); }
    @Override protected void onResume() { super.onResume(); if (surface != null) surface.onResume(); }
}
