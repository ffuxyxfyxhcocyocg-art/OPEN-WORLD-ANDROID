package com.openworld.game;

import android.content.Context;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class ContentUpdater {
    private static final String MANIFEST_URL =
        "https://raw.githubusercontent.com/ffuxyxfyxhcocyocg-art/OPEN-WORLD-ANDROID/main/content/manifest.json";
    private static final ExecutorService EXEC = Executors.newSingleThreadExecutor();
    public interface Callback { void onResult(String message, JSONObject world); }
    private ContentUpdater() {}

    public static void check(Context context, Callback callback) {
        Context app = context.getApplicationContext();
        EXEC.execute(() -> {
            File dir = new File(app.getFilesDir(), "remote-content");
            File current = new File(dir, "world.json");
            try {
                JSONObject manifest = new JSONObject(new String(download(MANIFEST_URL), StandardCharsets.UTF_8));
                int remoteVersion = manifest.getInt("version");
                if (remoteVersion < 1) throw new Exception("Versão remota inválida");
                int localVersion = app.getSharedPreferences("content", Context.MODE_PRIVATE).getInt("version", 0);
                if (remoteVersion > localVersion || !current.exists()) {
                    if (!dir.exists() && !dir.mkdirs()) throw new Exception("Não foi possível criar pasta");
                    String path = manifest.getString("content_url");
                    String expected = manifest.optString("sha256", "");
                    if (!path.startsWith("https://raw.githubusercontent.com/")) throw new Exception("URL não permitida");
                    if (!expected.matches("(?i)[0-9a-f]{64}")) throw new Exception("Hash SHA-256 ausente ou inválido");
                    byte[] bytes = download(path);
                    if (!expected.equalsIgnoreCase(sha256(bytes))) throw new Exception("SHA-256 inválido");
                    JSONObject parsed = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
                    WorldConfig.fromJson(parsed);
                    File temp = new File(dir, "world.json.tmp");
                    File backup = new File(dir, "world.json.bak");
                    try (FileOutputStream out = new FileOutputStream(temp)) { out.write(bytes); out.getFD().sync(); }

                    if (backup.exists() && !backup.delete()) throw new Exception("Não foi possível limpar backup");
                    if (current.exists() && !current.renameTo(backup)) throw new Exception("Não foi possível proteger conteúdo atual");
                    if (!temp.renameTo(current)) {
                        if (backup.exists()) backup.renameTo(current);
                        throw new Exception("Não foi possível finalizar atualização");
                    }
                    if (backup.exists()) backup.delete();

                    app.getSharedPreferences("content", Context.MODE_PRIVATE).edit().putInt("version", remoteVersion).apply();
                    callback.onResult("Hot Update aplicado • v" + remoteVersion, parsed);
                    return;
                }
                callback.onResult("Sem novas atualizações • v" + localVersion, readWorld(current));
            } catch (Exception ex) {
                try {
                    if (current.exists()) callback.onResult("Offline • usando mapa salvo", readWorld(current));
                    else callback.onResult("Conteúdo remoto indisponível • mapa padrão", null);
                } catch (Exception ignored) {
                    callback.onResult("Conteúdo remoto indisponível • mapa padrão", null);
                }
            }
        });
    }

    private static JSONObject readWorld(File file) throws Exception {
        try (FileInputStream in = new FileInputStream(file); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096]; int n;
            while ((n = in.read(buffer)) != -1) out.write(buffer, 0, n);
            return new JSONObject(new String(out.toByteArray(), StandardCharsets.UTF_8));
        }
    }

    private static byte[] download(String address) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(address).openConnection();
        c.setConnectTimeout(8000); c.setReadTimeout(12000); c.setInstanceFollowRedirects(false);
        try {
            int code = c.getResponseCode();
            if (code < 200 || code >= 300) throw new Exception("HTTP " + code);
            try (InputStream in = c.getInputStream(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[8192]; int n, total = 0;
                while ((n = in.read(buffer)) != -1) {
                    total += n;
                    if (total > 8 * 1024 * 1024) throw new Exception("Conteúdo excede limite");
                    out.write(buffer, 0, n);
                }
                return out.toByteArray();
            }
        } finally { c.disconnect(); }
    }

    private static String sha256(byte[] bytes) throws Exception {
        byte[] hash = MessageDigest.getInstance("SHA-256").digest(bytes);
        StringBuilder s = new StringBuilder();
        for (byte b : hash) s.append(String.format(Locale.US, "%02x", b));
        return s.toString();
    }
}
