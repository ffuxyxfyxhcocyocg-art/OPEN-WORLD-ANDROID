# OPEN WORLD BR — Godot Android

O jogo Android é exportado pelo projeto Godot 4.4.1 em `godot/`. A implementação antiga baseada em Android WebView/HTML foi removida do caminho de compilação.

## APK Android
- Workflow: `.github/workflows/native-godot-android.yml`.
- Exportação: Godot 4.4.1, Android ARM64, renderer GL Compatibility.
- Artefato: `OPEN-WORLD-GODOT-ANDROID`.

## Atualização automática de conteúdo
- `godot/scripts/remote_updater.gd` consulta os manifestos e valida SHA-256.
- `updates/manifest.json` aponta para o pacote `.pck` publicado no GitHub Release `vms-city-live`.
- `content/manifest.json` controla a configuração remota `content/world.json`.
- O pacote é carregado no início do app; atualizações baixadas entram ao reiniciar a cena/jogo.
- Cenas, modelos, texturas, sons e outros recursos compatíveis podem ser enviados no `.pck` sem reinstalar o APK.
- Mudanças no código nativo, engine, permissões ou funcionalidades que não existam no APK ainda exigem uma nova versão do app.

## Estrutura
- `godot/`: jogo 3D nativo Godot.
- `godot/models/midas.glb`: personagem Midas.
- `content/`: manifesto e configuração remota.
- `updates/`: manifesto do pacote remoto.
- `server/`: servidor WebSocket de multiplayer.

Não existe mais WebView/HTML como motor principal do aplicativo.