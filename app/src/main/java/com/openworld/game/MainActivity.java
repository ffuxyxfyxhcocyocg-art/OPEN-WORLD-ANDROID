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
import android.widget.Toast;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class MainActivity extends Activity {
    private static final String GAME_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/app/src/main/assets/game/index.html";
    private static final String BASE_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/app/src/main/assets/game/";
    private static final String VERSION_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/version.txt";
    private WebView gameView;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private String currentVersion = "";
    private String loadedHtml = "";
    private boolean loadingRemote = false;
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
        gameView.setWebViewClient(new WebViewClient());
        gameView.setWebChromeClient(new WebChromeClient());
        setContentView(gameView);
        // Abre a cópia local imediatamente e substitui pela versão remota assim que baixar.
        gameView.loadUrl("file:///android_asset/game/index.html");
        loadRemoteGame();
        checkRemoteVersion();
    }

    private String downloadText(String address) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(address + "?nocache=" + System.currentTimeMillis()).openConnection();
        connection.setConnectTimeout(12000);
        connection.setReadTimeout(15000);
        connection.setUseCaches(false);
        connection.setInstanceFollowRedirects(true);
        connection.setRequestProperty("Cache-Control", "no-cache, no-store");
        connection.setRequestProperty("Pragma", "no-cache");
        connection.setRequestProperty("User-Agent", "OpenWorldAndroid/2.0");
        try {
            int code = connection.getResponseCode();
            if (code != HttpURLConnection.HTTP_OK) throw new Exception("HTTP " + code);
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

    private void loadRemoteGame() {
        if (loadingRemote || gameView == null) return;
        loadingRemote = true;
        new Thread(() -> {
            String html = null;
            String failure = "";
            try {
                html = downloadText(GAME_URL);
                if (html == null || !html.toLowerCase().contains("<html")) {
                    throw new Exception("resposta não contém HTML");
                }
            } catch (Exception error) {
                failure = error.getClass().getSimpleName() + ": " + error.getMessage();
            }
            final String result = html;
            final String errorText = failure;
            runOnUiThread(() -> {
                loadingRemote = false;
                if (gameView == null || isFinishing()) return;
                if (result != null) {
                    boolean changed = !result.equals(loadedHtml);
                    loadedHtml = result;
                    if (changed) {
                        gameView.loadDataWithBaseURL(BASE_URL, result, "text/html", "UTF-8", null);
                    }
                } else if (loadedHtml.isEmpty()) {
                    Toast.makeText(this, "Não foi possível atualizar o jogo: " + errorText, Toast.LENGTH_LONG).show();
                }
            });
        }).start();
    }

    private void checkRemoteVersion() {
        if (checkingVersion) return;
        checkingVersion = true;
        new Thread(() -> {
            String found = "";
            try { found = downloadText(VERSION_URL).trim(); } catch (Exception ignored) {}
            final String version = found;
            runOnUiThread(() -> {
                checkingVersion = false;
                if (version.isEmpty() || isFinishing()) return;
                if (currentVersion.isEmpty()) {
                    currentVersion = version;
                } else if (!currentVersion.equals(version)) {
                    // Nunca substituir o HTML enquanto a partida está aberta.
                    // A versão nova será baixada e aplicada somente ao abrir o app novamente.
                    currentVersion = version;
                    Toast.makeText(this, "Atualização disponível. Ela será aplicada quando você abrir o jogo novamente.", Toast.LENGTH_LONG).show();
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
