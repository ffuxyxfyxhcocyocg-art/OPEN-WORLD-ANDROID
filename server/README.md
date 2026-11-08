# Open World BR — servidor online

Servidor WebSocket de salas e sincronização básica de jogadores para o jogo Three.js.

## Publicar no Render
1. Crie/conecte o projeto Render ao repositório GitHub.
2. Selecione **New > Blueprint** e escolha este repositório.
3. O Render detecta `render.yaml` e cria o serviço `open-world-br-realtime`.
4. Após o deploy, copie a URL HTTPS gerada. O endereço WebSocket correspondente é o mesmo host com `https://` trocado por `wss://` e o caminho `/ws`.
5. Abra o jogo com o parâmetro `?server=wss://SEU-HOST.onrender.com/ws` para testar a conexão.

## Endpoints
- `GET /health` — estado do serviço.
- `WSS /ws` — lobby, estado da partida, zona e posições dos jogadores.

## Limites desta primeira versão
- Sala pública única, até 40 conexões.
- Lobby de 12 s, contagem de 5 s e zona sincronizada.
- Sincroniza nome e posição dos jogadores; não implementa persistência nem autoridade completa de simulação.
- Plano gratuito pode suspender o serviço quando inativo, causando demora na primeira conexão.
