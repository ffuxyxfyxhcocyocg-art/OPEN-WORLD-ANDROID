package com.openworld.game;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

public class MainActivity extends Activity {
    private static final String GAME_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/app/src/main/assets/game/index.html";
    private static final String VERSION_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/version.txt";
    private WebView gameView;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private String currentVersion = "";
    private boolean showingLocalFallback = false;
    private boolean remoteLoaded = false;
    private boolean checkingVersion = false;

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
        settings.setCacheMode(WebSettings.LOAD_NO_CACHE);
        gameView.setWebChromeClient(new WebChromeClient());
        gameView.setWebViewClient(new WebViewClient() {
            @Override public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                if (url != null && url.startsWith("https://raw.githubusercontent.com/")) {
                    remoteLoaded = true;
                    showingLocalFallback = false;
                }
            }

            @Override public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                super.onReceivedError(view, request, error);
                if (request != null && request.isForMainFrame() && !remoteLoaded && !showingLocalFallback) {
                    showingLocalFallback = true;
                    view.loadUrl("file:///android_asset/game/index.html");
                }
            }
        });
        setContentView(gameView);
        loadRemoteGame();
        checkRemoteVersion();
    }

    private void loadRemoteGame() {
        if (gameView == null) return;
        remoteLoaded = false;
        showingLocalFallback = false;
        gameView.loadUrl(GAME_URL + "?hot=" + System.currentTimeMillis());
    }

    private String downloadVersion() throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(VERSION_URL + "?t=" + System.currentTimeMillis()).openConnection();
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(10000);
        connection.setUseCaches(false);
        connection.setRequestProperty("Cache-Control", "no-cache");
        connection.setInstanceFollowRedirects(true);
        try {
            int code = connection.getResponseCode();
            if (code != HttpURLConnection.HTTP_OK) throw new Exception("HTTP " + code);
            BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
            String version = reader.readLine();
            reader.close();
            return version == null ? "" : version.trim();
        } finally {
            connection.disconnect();
        }
    }

    private void checkRemoteVersion() {
        if (checkingVersion) return;
        checkingVersion = true;
        new Thread(() -> {
            String found = "";
            try { found = downloadVersion(); } catch (Exception ignored) {}
            final String version = found;
            runOnUiThread(() -> {
                checkingVersion = false;
                if (version.isEmpty() || isFinishing()) return;
                if (currentVersion.isEmpty()) {
                    currentVersion = version;
                } else if (!currentVersion.equals(version)) {
                    currentVersion = version;
                    loadRemoteGame();
                }
            });
        }).start();
    }

    private final Runnable updateCheck = new Runnable() {
        @Override public void run() {
            checkRemoteVersion();
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
            gameView.stopLoading();
            gameView.loadUrl("about:blank");
            gameView.destroy();
            gameView = null;
        }
        super.onDestroy();
    }
}
