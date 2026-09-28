const DEFAULT_TIMEOUT_MS = 60000;

/**
 * Pulls the plain-text body out of a Baileys WAMessage, unwrapping one level
 * of ephemeralMessage (disappearing-messages chats wrap every message in
 * this). Returns null for anything without a text body — media, reactions,
 * protocol/system messages, etc.
 */
export function extractText(message) {
  const content = message?.message?.ephemeralMessage?.message ?? message?.message;
  if (!content) return null;
  if (typeof content.conversation === 'string' && content.conversation.trim()) {
    return content.conversation.trim();
  }
  if (typeof content.extendedTextMessage?.text === 'string' && content.extendedTextMessage.text.trim()) {
    return content.extendedTextMessage.text.trim();
  }
  return null;
}

/**
 * Decides whether an incoming message should get an automated RAG reply.
 * Excludes: our own outbound messages (fromMe), group/broadcast chats
 * (@g.us / status@broadcast — a customer support assistant has no business
 * replying into a group), and anything with no extractable text.
 */
export function shouldAutoReply(message) {
  const jid = message?.key?.remoteJid;
  if (!jid || message?.key?.fromMe) return false;
  if (jid.endsWith('@g.us') || jid === 'status@broadcast') return false;
  return extractText(message) !== null;
}

/**
 * Extracts the incremental text token from one decoded SSE `data:` payload,
 * tolerant of both Workers AI streaming shapes — see ApiService.streamRagChat
 * in the Flutter app, which parses the same two shapes for the same reason.
 */
export function extractSseToken(decoded) {
  if (!decoded || typeof decoded !== 'object') return null;
  if (typeof decoded.response === 'string') return decoded.response;
  const delta = decoded.choices?.[0]?.delta;
  if (typeof delta?.content === 'string') return delta.content;
  return null;
}

/**
 * Reads a fetch Response's SSE body to completion and returns the
 * concatenated assistant text. WhatsApp has no notion of a streaming
 * message, so unlike the Flutter chat UI this waits for the full reply
 * before sending anything.
 */
export async function collectSseText(response) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let text = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const events = buffer.split('\n\n');
    buffer = events.pop() ?? '';
    for (const event of events) {
      const line = event.trim();
      if (!line.startsWith('data:')) continue;
      const data = line.slice(5).trim();
      if (!data || data === '[DONE]') continue;
      try {
        const token = extractSseToken(JSON.parse(data));
        if (token) text += token;
      } catch {
        // Malformed SSE fragment — skip it rather than abort the reply.
      }
    }
  }
  return text;
}

/**
 * Calls the Django RAG proxy (see backend/api/services/rag_service.py) and
 * returns the full assistant reply as plain text.
 */
export async function fetchRagReply(message, { backendUrl, timeoutMs = DEFAULT_TIMEOUT_MS }) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(`${backendUrl}/api/rag/chat/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message }),
      signal: controller.signal,
    });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new Error(`RAG proxy returned ${res.status}: ${body.slice(0, 200)}`);
    }
    return await collectSseText(res);
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Top-level handler wired to socket.js's `messages.upsert` event (see
 * index.js). Deliberately opt-in via `enabled` — auto-replying on the real,
 * already-linked WhatsApp session is a production behaviour change, not a
 * contained addition, so it defaults to off (AUTO_REPLY_ENABLED env var).
 */
export async function handleIncomingMessage(message, { enabled, backendUrl, sendTextMessage, logger }) {
  if (!enabled || !shouldAutoReply(message)) return;

  const jid = message.key.remoteJid;
  const text = extractText(message);
  try {
    const reply = await fetchRagReply(text, { backendUrl });
    if (reply.trim()) {
      await sendTextMessage(jid, reply.trim());
    }
  } catch (err) {
    logger?.error?.({ err, jid }, 'RAG auto-reply failed');
  }
}
