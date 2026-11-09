# SR Battle Royale BR — Android 0.3.0

Implementação **nova e independente em Godot 4** inspirada na estrutura de [Iswenzz/SR-BattleRoyale](https://github.com/Iswenzz/SR-BattleRoyale), mod de Call of Duty 4. O jogo anterior do usuário permanece na branch `main` sem alterações.

## Recursos implementados no protótipo

- **Cenário 3D original para Android**: ilha, areia, mar animado, ruas, cidade, edifícios, janelas, armazém, farol, porto, floresta de 128 árvores instanciadas, sombras simplificadas e materiais procedurais autorais. **Não é o mapa original `mp_br_blackout`.**
- **Partida**: lobby, voo de transporte, salto, paraquedas, cinco etapas de zona segura com dano fora da área e final de partida.
- **Suprimentos**: 18 caixas recolhíveis de munição, kits e escudos; barra de saúde, HUD e inventário simples.
- **Combate arcade**: três equipamentos fictícios, munição, recarga, alvo central, traçantes luminosos, efeito de impacto, nove drones/alvos com pontuação e reaparecimento.
- **Multiplayer LAN experimental**: Godot ENet, criar/entrar em sala por IP, no máximo oito participantes, sincronização básica de avatares e sinalização de dano mediada pelo anfitrião. **Não há servidor público na Internet, matchmaking nem teste comprovado de duas pessoas conectadas.** Para conectar fora da mesma rede, seria necessário hospedar um servidor próprio e configurar conectividade.
- **Personagem**: importação do arquivo `midas.glb` já presente no repositório para Godot; há avatar substituto caso o modelo não seja importado.
- **Android nativo**: controles de toque, renderizador Compatibility, build automatizada e teste básico de inicialização da cena.

## O que NÃO foi convertido

O repositório original contém `maps/mp/mp_br_blackout.gsc`, que configura zonas e eventos, **mas não contém uma malha do cenário 3D pronta para Godot**. Os recursos `.gsc`, `.iwi` e assets de Call of Duty 4 usam formatos e motor diferentes e não foram importados nem redistribuídos nesta versão. Os modelos e os visuais de terreno deste projeto foram criados do zero ou pertencem ao repositório original do usuário.

Também não há: mapa `mp_br_blackout` idêntico, reproduções dos sons e modelos de CoD4, combate completo com todas as armas do mod, partidas persistentes de 30–40 pessoas e serviço online público. Esta é uma base própria, não o mod completo portado.

## Arquivos

- `godot/scripts/main.gd` — cena inicial, jogador, HUD, sistema de atualização.
- `godot/scripts/arena_world.gd` — terreno, ambiente, cidade, paisagem e materiais originais.
- `godot/scripts/player.gd` — movimento, câmera, paraquedas, importação do Midas.
- `godot/scripts/battle_royale.gd` — fase da partida, voo, zona, suprimentos e saúde.
- `godot/scripts/arcade_combat.gd` — combate arcade, visual de tiro e alvos de treino.
- `godot/scripts/lan_multiplayer.gd` — ENet, criar/entrar em sala e sincronização básica.
- `godot/scripts/verify_scene.gd` — teste de integração do projeto inicializado.
- `.github/workflows/godot-android.yml` — importação do modelo, testes, APK e GitHub Release.

## Executar e instalar

Abra a pasta `godot/` com Godot 4.4.1. No GitHub, acesse **Actions → SR Battle Royale Android** para compilar na branch `sr-battleroyale-godot` e baixar o artefato APK quando a execução ficar verde. A compilação usa Android arm64 e instala como `com.openworld.srbattleroyale`, sem substituir o antigo Open World BR.

Por ser um jogo Godot nativo, alterar o código exige nova instalação do APK. O botão de atualização apenas abre a página de download — **não instala atualizações silenciosamente**.

## Referências e licença

A lógica de fases foi inspirada na organização do repositório original: `_match.gsc`, `_plane.gsc`, `_zone.gsc`, `_game.gsc` e `_inventory.gsc`. Nenhum código GSC é executado no Android. Consultar [Iswenzz/SR-BattleRoyale](https://github.com/Iswenzz/SR-BattleRoyale) e [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.html). Texto de licença incluído em `godot/LICENSE`.

**Estado de qualidade:** scripts passam por compilação e teste da cena no CI quando indicados como aprovados; desempenho, gráficos reais e multiplayer entre celulares ainda exigem verificação presencial.
