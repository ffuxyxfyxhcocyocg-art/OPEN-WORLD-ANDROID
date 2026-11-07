# OPEN WORLD — Android

Projeto Android nativo em Java + OpenGL ES 2.0. Não usa HTML nem engine externa.

## Primeira base
- Aplicativo Android em orientação paisagem.
- Cena 3D renderizada por OpenGL ES.
- Cidade procedural inicial para validar câmera, escala e desempenho.
- Controles de toque: lado esquerdo movimenta; lado direito gira a câmera.
- Verificador de conteúdo remoto.

## Atualizações sem reinstalar o APK
O app consulta `content/manifest.json` no branch `main`. Se a versão remota for maior, baixa `content/world.json` para a pasta privada do aplicativo. Assim podemos atualizar configurações e conteúdo remoto sem reinstalar o APK.

**Limite importante:** isso atualiza conteúdo e dados compatíveis. Alterações no código Java, bibliotecas, renderizador ou permissões exigem uma nova compilação/instalação do APK. O app não executa código nativo baixado do servidor.

## Abrir
Abra a pasta no Android Studio. Instale Android SDK 35, JDK 17, Android Gradle Plugin e sincronize o Gradle. Execute no aparelho Android com OpenGL ES 2.0.

## Estrutura
- `app/src/main/java/com/openworld/game/MainActivity.java`: Activity e entrada de toque.
- `GameRenderer.java`: renderização 3D OpenGL ES.
- `ContentUpdater.java`: consulta de versão e download seguro de dados.
- `content/manifest.json` e `content/world.json`: conteúdo remoto.
