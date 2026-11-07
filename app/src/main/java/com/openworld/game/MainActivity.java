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

public class MainActivity extends Activity {
    private static final String GAME_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/app/src/main/assets/game/index.html";
    private WebView gameView;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean showingLocalFallback = false;
    private boolean remoteLoaded = false;

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
    }

    private void loadRemoteGame() {
        if (gameView == null) return;
        remoteLoaded = false;
        showingLocalFallback = false;
        gameView.loadUrl(GAME_URL + "?hot=" + System.currentTimeMillis());
    }

    private final Runnable updateCheck = new Runnable() {
        @Override public void run() {
            if (!isFinishing() && gameView != null && !showingLocalFallback) {
                // Atualiza a página remota sem depender de cache HTTP antigo.
                loadRemoteGame();
            } else if (!isFinishing() && gameView != null) {
                // Se iniciou pelo HTML local, tenta novamente buscar a versão remota.
                loadRemoteGame();
            }
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
