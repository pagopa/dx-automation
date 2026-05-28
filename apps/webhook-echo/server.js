import { createHmac, timingSafeEqual } from 'node:crypto';
import { appendFile, mkdir } from 'node:fs/promises';
import { createServer } from 'node:http';
import { join } from 'node:path';

const port = Number.parseInt(process.env.PORT ?? '3000', 10);
const host = process.env.HOST ?? '0.0.0.0';
const githubWebhookSecret = process.env.GITHUB_WEBHOOK_SECRET ?? '';
const eventsDirectory = process.env.EVENTS_DIR ?? join(process.cwd(), 'events');

function readRequestBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];

    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function verifyGithubSignature(signatureHeader, rawBody) {
  if (!githubWebhookSecret) {
    return {
      enabled: false,
      valid: null,
      reason: 'GITHUB_WEBHOOK_SECRET non configurato'
    };
  }

  if (!signatureHeader) {
    return {
      enabled: true,
      valid: false,
      reason: 'Header x-hub-signature-256 mancante'
    };
  }

  const expected = `sha256=${createHmac('sha256', githubWebhookSecret).update(rawBody).digest('hex')}`;
  const signatureBuffer = Buffer.from(signatureHeader);
  const expectedBuffer = Buffer.from(expected);

  if (signatureBuffer.length !== expectedBuffer.length) {
    return {
      enabled: true,
      valid: false,
      reason: 'Lunghezza firma non valida'
    };
  }

  return {
    enabled: true,
    valid: timingSafeEqual(signatureBuffer, expectedBuffer),
    reason: timingSafeEqual(signatureBuffer, expectedBuffer) ? 'Firma valida' : 'Firma non valida'
  };
}

function tryParseJson(text) {
  if (!text) {
    return null;
  }

  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function getGithubRefSummary(eventName, parsedBody) {
  const ref = parsedBody && typeof parsedBody === 'object' ? parsedBody.ref ?? null : null;
  const isTagPush = eventName === 'push' && typeof ref === 'string' && ref.startsWith('refs/tags/');

  return {
    ref,
    isTagPush,
    tagName: isTagPush ? ref.replace('refs/tags/', '') : null
  };
}

function getEventFileName(eventName) {
  if (typeof eventName !== 'string' || !eventName.trim()) {
    return 'unknown.jsonl';
  }

  return `${eventName.replace(/[^a-z0-9_-]+/gi, '-').toLowerCase()}.jsonl`;
}

async function persistEvent(payload) {
  const fileName = getEventFileName(payload.github.event);
  const filePath = join(eventsDirectory, fileName);

  await mkdir(eventsDirectory, { recursive: true });
  await appendFile(filePath, `${JSON.stringify(payload)}\n`, 'utf8');

  return filePath;
}

const server = createServer(async (req, res) => {
  try {
    const rawBody = await readRequestBody(req);
    const bodyText = rawBody.toString('utf8');
    const parsedBody = tryParseJson(bodyText);
    const eventName = req.headers['x-github-event'] ?? null;
    const signatureCheck = verifyGithubSignature(req.headers['x-hub-signature-256'], rawBody);
    const refSummary = getGithubRefSummary(eventName, parsedBody);

    const payload = {
      receivedAt: new Date().toISOString(),
      method: req.method,
      url: req.url,
      headers: req.headers,
      github: {
        event: eventName,
        delivery: req.headers['x-github-delivery'] ?? null,
        hookId: req.headers['x-github-hook-id'] ?? null,
        hookInstallationTargetId: req.headers['x-github-hook-installation-target-id'] ?? null,
        ref: refSummary.ref,
        isTagPush: refSummary.isTagPush,
        tagName: refSummary.tagName,
        signature: signatureCheck
      },
      bodyText,
      bodyJson: parsedBody
    };
    const storedAt = await persistEvent(payload);

    console.log(JSON.stringify({ ...payload, storedAt }, null, 2));

    res.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
    res.end(
      JSON.stringify(
        {
          ok: true,
          receivedAt: payload.receivedAt,
          github: payload.github,
          storedAt,
          bodyPreview: bodyText.slice(0, 500)
        },
        null,
        2
      )
    );
  } catch (error) {
    console.error(error);
    res.writeHead(500, { 'content-type': 'application/json; charset=utf-8' });
    res.end(
      JSON.stringify({
        ok: false,
        error: error instanceof Error ? error.message : 'Errore interno'
      })
    );
  }
});

server.listen(port, host, () => {
  console.log(`Webhook echo server in ascolto su http://${host}:${port}`);
});