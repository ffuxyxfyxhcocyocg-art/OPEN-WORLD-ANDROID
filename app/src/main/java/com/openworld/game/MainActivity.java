package com.openworld.game;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class MainActivity extends Activity {
    private static final String GAME_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/app/src/main/assets/game/index.html";
    private static final String BASE_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/app/src/main/assets/game/";
    private WebView gameView;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private String loadedHtml = "";
    private boolean loadingRemote = false;

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_LAYOUT_STABLE |
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        );
        gameView = new WebView(this);
        gameView.setBackgroundColor(0xFF8FC3DF);
        gameView.setLayerType(View.LAYER_TYPE_HARDWARE, null);
        WebSettings settings = gameView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setLoadsImagesAutomatically(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        gameView.setWebViewClient(new WebViewClient());
        gameView.setWebChromeClient(new WebChromeClient());
        setContentView(gameView);
        loadLatestGame(false);
    }

    private String downloadText(String address) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(address + "?t=" + System.currentTimeMillis()).openConnection();
        connection.setConnectTimeout(7000);
        connection.setReadTimeout(10000);
        connection.setRequestProperty("Cache-Control", "no-cache");
        connection.setRequestProperty("User-Agent", "OpenWorldAndroid/1.0");
        try {
            InputStream input = connection.getInputStream();
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int count;
            while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
            input.close();
            return new String(output.toByteArray(), StandardCharsets.UTF_8);
        } finally {
            connection.disconnect();
        }
    }

    private void loadLatestGame(boolean updateOnly) {
        if (loadingRemote || gameView == null) return;
        loadingRemote = true;
        new Thread(() -> {
            String html = null;
            try { html = downloadText(GAME_URL); } catch (Exception ignored) {}
            final String result = html;
            runOnUiThread(() -> {
                loadingRemote = false;
                if (gameView == null) return;
                if (result != null && result.contains("<html")) {
                    boolean changed = !result.equals(loadedHtml);
                    loadedHtml = result;
                    if (!updateOnly || changed) {
                        gameView.loadDataWithBaseURL(BASE_URL, result, "text/html", "UTF-8", null);
                    }
                } else if (!updateOnly && loadedHtml.isEmpty()) {
                    gameView.loadUrl("file:///android_asset/game/index.html");
                }
            });
        }).start();
    }

    private final Runnable updateCheck = new Runnable() {
        @Override public void run() {
            loadLatestGame(true);
            handler.postDelayed(this, 60000);
        }
    };

    @Override protected void onPause() {
        handler.removeCallbacks(updateCheck);
        if (gameView != null) gameView.onPause();
        super.onPause();
    }

    @Override protected void onResume() {
        super.onResume();
        if (gameView != null) gameView.onResume();
        handler.removeCallbacks(updateCheck);
        handler.postDelayed(updateCheck, 60000);
    }

    @Override protected void onDestroy() {
        handler.removeCallbacks(updateCheck);
        if (gameView != null) {
            gameView.loadUrl("about:blank");
            gameView.stopLoading();
            gameView.destroy();
            gameView = null;
        }
        super.onDestroy();
    }
}
