# SR Battle Royale BR — Android (Godot 4)

Nova base nativa e separada do aplicativo WebView anterior. Esta é uma **adaptação em desenvolvimento** das mecânicas de [SR-BattleRoyale](https://github.com/Iswenzz/SR-BattleRoyale), um mod de **Call of Duty 4**, para Godot 4 e Android.

## O que já existe nesta base

- Ambiente 3D e cidade low-poly para Android, com câmera em terceira pessoa e joystick de toque.
- Fases do modo Battle Royale: lobby solo (8s) → voo de transporte → salto → queda com paraquedas → sobrevivência.
- Zona segura que diminui em cinco etapas e reduz a saúde/escudo do jogador fora do limite.
- 18 caixas de suprimentos, coleta por proximidade, inventário simples, kits de cura e escudos.
- HUD de partida e botão para saltar do transporte.
- Modelo GLB Midas importado no projeto Godot durante a build; avatar alternativo se o modelo falhar.
- APK compilado pela GitHub Actions do branch `sr-battleroyale-godot`, com package independente `com.openworld.srbattleroyale`.

## Ainda não implementado

- Multiplayer real com dezenas de jogadores: requer rede, servidor e sincronização.
- Armas completas, inventário de múltiplos slots, animações dedicadas, veículos e bots.
- Mapa CoD4 `mp_br_blackout`: **o mapa original não pode ser carregado pelo Godot** sem uma conversão e autorizações apropriadas.
- Os arquivos `.gsc`, `.iwi`, `.iwd`, `.ff` de CoD4 **não rodam no Android/Godot**. Não foi transferido o jogo/mod completo nem os assets originais de CoD4.
- Não possui atualizações automáticas de código sem instalar outro APK: o atualizador abre a página do release quando uma versão nova é publicada.

## Organização

- `scripts/main.gd`: cenário e interface mobile existentes.
- `scripts/player.gd`: controle, câmera touch, paraquedas, importação do Midas.
- `scripts/battle_royale.gd`: fases, voo, zona, loot e HUD (mecânicas adaptadas).
- `.github/workflows/godot-android.yml`: importação de modelos, validação e export Android.

## Origem e créditos

A referência de design e organização da partida é o projeto livre [Iswenzz/SR-BattleRoyale](https://github.com/Iswenzz/SR-BattleRoyale), licenciado em [GPL-3.0](https://github.com/Iswenzz/SR-BattleRoyale/blob/master/LICENSE). O código de Godot foi reescrito em GDScript, não é um empacotamento de CoD4.

Mapeamento da adaptação:
- `battleroyale/core/_match.gsc` → gerenciamento de lobby e início da rodada.
- `battleroyale/core/_plane.gsc` → transporte e salto.
- `battleroyale/core/_zone.gsc` → redução da zona.
- `battleroyale/core/_game.gsc` + `huds/_inventory.gsc` → suprimentos e inventário.

Não foram copiados materiais, personagens, mapas, áudio ou texturas proprietários de Call of Duty 4.

## Como compilar

No GitHub, vá até **Actions → SR Battle Royale Android**, selecione a execução recente do branch `sr-battleroyale-godot` e baixe o artifact `SR-BattleRoyale-Android` quando a execução estiver concluída. Dentro do ZIP haverá um APK debug.

A build exige Godot 4.4.1, templates Android, JDK 17 e Android SDK. O workflow configura essas dependências.

**Nota:** isto é um protótipo jogável em desenvolvimento, não o jogo CoD4 completo, e ainda precisa de testes reais de gameplay em Android.
