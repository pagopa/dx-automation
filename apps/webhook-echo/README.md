# Webhook Echo Server

Server HTTP minimale per ispezionare richieste in ingresso, utile per webhook GitHub e test locali tramite `cloudflared`.

## Avvio locale

```bash
pnpm --filter @pagopa/dx-webhook-echo start
```

Opzioni supportate:

- `PORT`: porta HTTP, default `3000`
- `HOST`: host bind, default `0.0.0.0`
- `GITHUB_WEBHOOK_SECRET`: se impostata, il server verifica `x-hub-signature-256`
- `EVENTS_DIR`: directory dove salvare gli eventi, default `apps/webhook-echo/events`

Esempio:

```bash
GITHUB_WEBHOOK_SECRET=my-secret PORT=3000 pnpm --filter @pagopa/dx-webhook-echo start
```

## Test locale

```bash
curl -X POST http://127.0.0.1:3000/webhook \
  -H 'content-type: application/json' \
  -d '{"hello":"world"}'
```

## Esposizione con cloudflared

```bash
cloudflared tunnel --url http://127.0.0.1:3000
```

`cloudflared` mostrerà un URL pubblico `https://...trycloudflare.com` da usare come payload URL del webhook GitHub.

## Configurazione webhook GitHub

Nel repository GitHub:

1. Vai in `Settings > Webhooks > Add webhook`
2. `Payload URL`: `https://<tuo-tunnel>/webhook`
3. `Content type`: `application/json`
4. `Secret`: usa lo stesso valore di `GITHUB_WEBHOOK_SECRET`
5. Seleziona `Let me select individual events`
6. Abilita almeno `Pushes`

Quando fai push di un tag, GitHub invia un evento `push`; nel payload troverai `ref` con valore del tipo `refs/tags/v1.2.3`.

## Cosa osservare

Nel log del server vedrai:

- headers completi
- evento GitHub (`x-github-event`)
- delivery id (`x-github-delivery`)
- body raw
- body JSON parsato quando valido
- esito verifica firma se hai configurato il secret

Inoltre ogni richiesta viene salvata su file distinti per tipo evento in formato JSON Lines:

- `events/push.jsonl`
- `events/ping.jsonl`
- `events/create.jsonl`
- `events/unknown.jsonl` se l'header evento manca

Per il tuo caso, i push di tag finiranno in `push.jsonl`; dentro ogni record troverai `github.ref`, `github.isTagPush` e `github.tagName`.