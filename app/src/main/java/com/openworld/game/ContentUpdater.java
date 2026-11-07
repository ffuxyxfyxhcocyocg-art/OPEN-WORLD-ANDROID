package com.openworld.game;

import android.content.Context;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
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
            String message;
            try {
                JSONObject manifest = new JSONObject(new String(download(MANIFEST_URL), StandardCharsets.UTF_8));
                int remoteVersion = manifest.getInt("version");
                if (!dir.exists() && !dir.mkdirs()) throw new Exception("Não foi possível criar pasta de conteúdo");
                int localVersion = app.getSharedPreferences("content", Context.MODE_PRIVATE).getInt("version", 0);
                if (remoteVersion > localVersion || !current.exists()) {
                    String path = manifest.getString("content_url");
                    String expected = manifest.optString("sha256", "");
                    if (!path.startsWith("https://raw.githubusercontent.com/")) throw new Exception("URL de conteúdo não permitida");
                    byte[] bytes = download(path);
                    if (!expected.isEmpty() && !expected.equalsIgnoreCase(sha256(bytes))) throw new Exception("Falha na verificação SHA-256");
                    JSONObject parsed = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
                    validateWorld(parsed);
                    File temp = new File(dir, "world.json.tmp");
                    try (FileOutputStream out = new FileOutputStream(temp)) { out.write(bytes); out.getFD().sync(); }
                    if (current.exists() && !current.delete()) throw new Exception("Não foi possível substituir conteúdo");
                    if (!temp.renameTo(current)) throw new Exception("Não foi possível finalizar atualização");
                    app.getSharedPreferences("content", Context.MODE_PRIVATE).edit().putInt("version", remoteVersion).apply();
                    message = "Novo conteúdo instalado • v" + remoteVersion;
                } else {
                    message = "Conteúdo atualizado • v" + localVersion;
                }
            } catch (Exception ex) {
                message = "Conteúdo local mantido • atualização indisponível";
            }

            JSONObject world = readCachedWorld(current);
            if (world == null) world = new JSONObject();
            callback.onResult(message, world);
        });
    }

    private static JSONObject readCachedWorld(File file) {
        if (!file.exists()) return null;
        try (FileInputStream in = new FileInputStream(file); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096]; int n;
            while ((n = in.read(buffer)) != -1) out.write(buffer, 0, n);
            JSONObject world = new JSONObject(new String(out.toByteArray(), StandardCharsets.UTF_8));
            validateWorld(world);
            return world;
        } catch (Exception ignored) { return null; }
    }

    private static void validateWorld(JSONObject world) throws Exception {
        JSONObject settings = world.optJSONObject("world_settings");
        if (settings == null) throw new Exception("Configuração do mundo ausente");
        int radius = settings.optInt("grid_radius", 5);
        double spacing = settings.optDouble("block_spacing", 8.0);
        if (radius < 2 || radius > 10 || spacing < 5.0 || spacing > 20.0)
            throw new Exception("Configuração do mundo fora dos limites");
    }

    private static byte[] download(String address) throws Exception {
        HttpURLConnection c=(HttpURLConnection)new URL(address).openConnection();
        c.setConnectTimeout(8000); c.setReadTimeout(12000); c.setInstanceFollowRedirects(false);
        try {
            int code=c.getResponseCode();
            if(code<200||code>=300) throw new Exception("HTTP "+code);
            try(InputStream in=c.getInputStream(); ByteArrayOutputStream out=new ByteArrayOutputStream()){
                byte[] buffer=new byte[8192]; int n, total=0;
                while((n=in.read(buffer))!=-1){ total+=n; if(total>8*1024*1024) throw new Exception("Conteúdo excede limite"); out.write(buffer,0,n); }
                return out.toByteArray();
            }
        } finally { c.disconnect(); }
    }
    private static String sha256(byte[] bytes) throws Exception {
        byte[] hash=MessageDigest.getInstance("SHA-256").digest(bytes);
        StringBuilder s=new StringBuilder();
        for(byte b:hash) s.append(String.format(Locale.US,"%02x",b));
        return s.toString();
    }
}
