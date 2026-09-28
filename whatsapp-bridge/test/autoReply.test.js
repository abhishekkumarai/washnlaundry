import test from 'node:test';
import assert from 'node:assert';
import {
  extractText,
  shouldAutoReply,
  extractSseToken,
  collectSseText,
} from '../src/autoReply.js';

test('extractText reads plain conversation text', () => {
  const msg = { message: { conversation: '  How much is a shirt? ' } };
  assert.strictEqual(extractText(msg), 'How much is a shirt?');
});

test('extractText reads extendedTextMessage text (e.g. a reply)', () => {
  const msg = { message: { extendedTextMessage: { text: 'Is my order ready?' } } };
  assert.strictEqual(extractText(msg), 'Is my order ready?');
});

test('extractText unwraps one level of ephemeralMessage', () => {
  const msg = { message: { ephemeralMessage: { message: { conversation: 'Hi' } } } };
  assert.strictEqual(extractText(msg), 'Hi');
});

test('extractText returns null for media/system messages with no text body', () => {
  assert.strictEqual(extractText({ message: { imageMessage: {} } }), null);
  assert.strictEqual(extractText({ message: null }), null);
  assert.strictEqual(extractText({}), null);
});

test('shouldAutoReply skips our own outbound messages', () => {
  const msg = {
    key: { remoteJid: '919876543210@s.whatsapp.net', fromMe: true },
    message: { conversation: 'sent by the shop' },
  };
  assert.strictEqual(shouldAutoReply(msg), false);
});

test('shouldAutoReply skips group and broadcast chats', () => {
  const group = {
    key: { remoteJid: '123-456@g.us', fromMe: false },
    message: { conversation: 'hey everyone' },
  };
  const broadcast = {
    key: { remoteJid: 'status@broadcast', fromMe: false },
    message: { conversation: 'status update' },
  };
  assert.strictEqual(shouldAutoReply(group), false);
  assert.strictEqual(shouldAutoReply(broadcast), false);
});

test('shouldAutoReply skips messages with no extractable text', () => {
  const msg = {
    key: { remoteJid: '919876543210@s.whatsapp.net', fromMe: false },
    message: { stickerMessage: {} },
  };
  assert.strictEqual(shouldAutoReply(msg), false);
});

test('shouldAutoReply accepts a genuine inbound text message', () => {
  const msg = {
    key: { remoteJid: '919876543210@s.whatsapp.net', fromMe: false },
    message: { conversation: 'What are your rates?' },
  };
  assert.strictEqual(shouldAutoReply(msg), true);
});

test('extractSseToken reads the text-generation shape', () => {
  assert.strictEqual(extractSseToken({ response: 'hello' }), 'hello');
});

test('extractSseToken reads the OpenAI-style chat delta shape', () => {
  assert.strictEqual(
    extractSseToken({ choices: [{ delta: { content: 'world' } }] }),
    'world',
  );
});

test('extractSseToken returns null for shapes with no token', () => {
  assert.strictEqual(extractSseToken({ choices: [{ delta: {} }] }), null);
  assert.strictEqual(extractSseToken({}), null);
  assert.strictEqual(extractSseToken(null), null);
});

test('collectSseText concatenates tokens across chunk boundaries', async () => {
  const events = [
    'data: {"response":"Hel"}\n\n',
    'data: {"response":"lo"}\n\n',
    'data: {"choices":[{"delta":{"content":" there"}}]}\n\n',
    'data: [DONE]\n\n',
  ];
  const encoder = new TextEncoder();
  const chunks = events.map((e) => encoder.encode(e));
  let i = 0;
  const reader = {
    read: async () => {
      if (i < chunks.length) return { done: false, value: chunks[i++] };
      return { done: true, value: undefined };
    },
  };
  const response = { body: { getReader: () => reader } };
  assert.strictEqual(await collectSseText(response), 'Hello there');
});

test('collectSseText tolerates a malformed SSE fragment without aborting', async () => {
  const events = ['data: not-json\n\n', 'data: {"response":"ok"}\n\n'];
  const encoder = new TextEncoder();
  const chunks = events.map((e) => encoder.encode(e));
  let i = 0;
  const reader = {
    read: async () => {
      if (i < chunks.length) return { done: false, value: chunks[i++] };
      return { done: true, value: undefined };
    },
  };
  const response = { body: { getReader: () => reader } };
  assert.strictEqual(await collectSseText(response), 'ok');
});
