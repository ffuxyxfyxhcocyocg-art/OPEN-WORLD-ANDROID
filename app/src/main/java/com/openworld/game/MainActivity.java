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
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class MainActivity extends Activity {
    private static final String GAME_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/app/src/main/assets/game/index.html";
    private static final String BASE_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/app/src/main/assets/game/";
    private static final String VERSION_URL = "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/version.txt";
    private static final String PREFS = "remote_game";
    private static final String VERSION_KEY = "version";
    private WebView gameView;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private String currentVersion = "";
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
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        gameView.setWebViewClient(new WebViewClient());
        gameView.setWebChromeClient(new WebChromeClient());
        setContentView(gameView);

        currentVersion = getSharedPreferences(PREFS, MODE_PRIVATE).getString(VERSION_KEY, "");
        loadCachedGame();
        refreshRemoteGame(false);
    }

    private File cachedGameFile() {
        return new File(getFilesDir(), "remote-game.html");
    }

    private void loadCachedGame() {
        File cached = cachedGameFile();
        if (!cached.isFile()) {
            showLoadingScreen();
            return;
        }
        try {
            byte[] bytes = readFile(cached);
            String html = new String(bytes, StandardCharsets.UTF_8);
            if (isValidHtml(html)) {
                gameView.loadDataWithBaseURL(BASE_URL, html, "text/html", "UTF-8", null);
            } else {
                showLoadingScreen();
            }
        } catch (Exception error) {
            showLoadingScreen();
        }
    }

    private void showLoadingScreen() {
        String html = "<!doctype html><html lang='pt-BR'><head><meta name='viewport' content='width=device-width,initial-scale=1'></head>" +
            "<body style='margin:0;background:#142735;color:#fff;font-family:sans-serif;display:grid;place-items:center;height:100vh;text-align:center'>" +
            "<div><h2 style='letter-spacing:3px'>OPEN WORLD BR</h2><p>Carregando jogo...</p></div></body></html>";
        gameView.loadDataWithBaseURL(BASE_URL, html, "text/html", "UTF-8", null);
    }

    private String downloadText(String address) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(address + "?nocache=" + System.currentTimeMillis()).openConnection();
        connection.setConnectTimeout(12000);
        connection.setReadTimeout(20000);
        connection.setUseCaches(false);
        connection.setInstanceFollowRedirects(true);
        connection.setRequestProperty("Cache-Control", "no-cache, no-store");
        connection.setRequestProperty("Pragma", "no-cache");
        connection.setRequestProperty("User-Agent", "OpenWorldAndroid/3.0");
        try {
            int code = connection.getResponseCode();
            if (code != HttpURLConnection.HTTP_OK) throw new Exception("HTTP " + code);
            try (InputStream input = connection.getInputStream(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[8192];
                int count, total = 0;
                while ((count = input.read(buffer)) != -1) {
                    total += count;
                    if (total > 20 * 1024 * 1024) throw new Exception("Jogo remoto excede 20 MB");
                    output.write(buffer, 0, count);
                }
                return new String(output.toByteArray(), StandardCharsets.UTF_8);
            }
        } finally {
            connection.disconnect();
        }
    }

    private boolean isValidHtml(String html) {
        return html != null && html.toLowerCase().contains("<html") && html.length() > 100;
    }

    private void refreshRemoteGame(boolean showUpdateMessage) {
        if (loadingRemote || gameView == null) return;
        loadingRemote = true;
        new Thread(() -> {
            String html = null;
            String version = "";
            String failure = "";
            try {
                version = downloadText(VERSION_URL).trim();
                if (version.isEmpty() || version.length() > 80) throw new Exception("versão remota inválida");
                html = downloadText(GAME_URL);
                if (!isValidHtml(html)) throw new Exception("arquivo do jogo inválido");
                File target = cachedGameFile();
                File temp = new File(getFilesDir(), "remote-game.html.tmp");
                try (FileOutputStream out = new FileOutputStream(temp)) {
                    out.write(html.getBytes(StandardCharsets.UTF_8));
                    out.getFD().sync();
                }
                if (target.exists() && !target.delete()) throw new Exception("não foi possível substituir cache antigo");
                if (!temp.renameTo(target)) throw new Exception("não foi possível salvar jogo atualizado");
                getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(VERSION_KEY, version).apply();
            } catch (Exception error) {
                failure = error.getClass().getSimpleName() + ": " + error.getMessage();
            }
            final String downloadedHtml = html;
            final String downloadedVersion = version;
            final String errorText = failure;
            runOnUiThread(() -> {
                loadingRemote = false;
                if (gameView == null || isFinishing()) return;
                if (downloadedHtml != null) {
                    boolean updated = !downloadedVersion.equals(currentVersion);
                    currentVersion = downloadedVersion;
                    // Aplicar somente durante a abertura/retorno ao app, nunca no meio da partida.
                    gameView.loadDataWithBaseURL(BASE_URL, downloadedHtml, "text/html", "UTF-8", null);
                    if (updated && showUpdateMessage) {
                        Toast.makeText(this, "Jogo atualizado automaticamente • v" + currentVersion, Toast.LENGTH_SHORT).show();
                    }
                } else if (cachedGameFile().isFile()) {
                    Toast.makeText(this, "Sem internet: usando a última versão salva.", Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(this, "Não foi possível baixar o jogo. Verifique a internet.", Toast.LENGTH_LONG).show();
                }
            });
        }).start();
    }

    private void checkRemoteVersion() {
        if (checkingVersion || loadingRemote) return;
        checkingVersion = true;
        new Thread(() -> {
            String version = "";
            try { version = downloadText(VERSION_URL).trim(); } catch (Exception ignored) {}
            final String found = version;
            runOnUiThread(() -> {
                checkingVersion = false;
                if (found.isEmpty() || isFinishing() || found.equals(currentVersion)) return;
                // O download completo ocorre ao voltar/abrir o jogo, evitando reiniciar uma partida.
                Toast.makeText(this, "Nova atualização disponível. Será baixada ao abrir o jogo novamente.", Toast.LENGTH_LONG).show();
            });
        }).start();
    }

    private final Runnable updateCheck = new Runnable() {
        @Override public void run() {
            checkRemoteVersion();
            handler.postDelayed(this, 60000);
        }
    };

    private byte[] readFile(File file) throws Exception {
        try (InputStream in = new java.io.FileInputStream(file); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            int n;
            while ((n = in.read(buffer)) != -1) out.write(buffer, 0, n);
            return out.toByteArray();
        }
    }

    @Override protected void onPause() {
        handler.removeCallbacks(updateCheck);
        if (gameView != null) gameView.onPause();
        super.onPause();
    }

    @Override protected void onResume() {
        super.onResume();
        if (gameView != null) gameView.onResume();
        if (!loadingRemote && gameView != null) refreshRemoteGame(true);
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
