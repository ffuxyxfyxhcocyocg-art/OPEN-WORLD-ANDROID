# SR Battle Royale ZERO — Android

## Nova base limpa

Este projeto foi criado como uma **reconstrução independente**, começando de zero, inspirada pelo mod [Iswenzz/SR-BattleRoyale](https://github.com/Iswenzz/SR-BattleRoyale) (GPL-3.0). Não é a branch do Open World BR, não usa os arquivos nem o HTML do aplicativo anterior.

Motor: Godot 4.4.1. Android arm64, modo horizontal, controles de toque.

## Primeira etapa

- Terreno 3D novo com ilha, praia, mar, estradas, prédios, árvores e pontos de referência.
- Personagem 3D feito do zero com câmera em terceira pessoa e joystick.
- Partida com espera, avião, salto com queda lenta, sobrevivência e zona que diminui.
- Coleta de caixas, cura, escudo, três slots de pulso arcade, drones de treino e HUD.
- Servidor de sala local via ENet para testes na mesma rede Wi-Fi (sem servidor público).

## Limitações explícitas

O repositório SR-BattleRoyale é um **mod de Call of Duty 4**; seus scripts GSC e recursos não funcionam diretamente no Android. A malha do mapa original MP_BR_BLACKOUT não está presente como GLB/FBX/OBJ compatível no repositório original. Nenhum modelo, textura ou áudio proprietário de CoD4 foi incluído. A conversão exata do mapa, a jogabilidade completa e partidas online abertas NÃO estão concluídas.

## Compilação

GitHub Actions, branch **sr-battleroyale-do-zero** → workflow **SR Zero Android** → APK **SR-BattleRoyale-Zero.apk**. Pode abrir \`game/\` no Godot 4.4.1 no PC. O APK é independente, com package \`com.srbattleroyale.zero\`.

## Créditos

Referência dos conceitos: SR-BattleRoyale (Iswenzz e colaboradores), sob licença GPL-3.0. Código Android original em GDScript; sem reutilizar seus arquivos de jogos ou modelos de CoD4.
