import test from 'node:test';
import assert from 'node:assert';
import { normalizeJid } from '../src/app.js';
import { enqueueSend, sleep } from '../src/queue.js';

test('normalizeJid properly converts various phone inputs to WhatsApp JID', () => {
  // 10-digit Indian number defaults to country code 91
  assert.strictEqual(normalizeJid('9876543210'), '919876543210@s.whatsapp.net');

  // With leading +91
  assert.strictEqual(normalizeJid('+91 98765 43210'), '919876543210@s.whatsapp.net');

  // With hyphens and spaces
  assert.strictEqual(normalizeJid('+91-98765-43210'), '919876543210@s.whatsapp.net');

  // Already formatted JID
  assert.strictEqual(normalizeJid('919876543210@s.whatsapp.net'), '919876543210@s.whatsapp.net');

  // Group JID
  assert.strictEqual(normalizeJid('1234567890-123456@g.us'), '1234567890-123456@g.us');

  // Empty / invalid
  assert.strictEqual(normalizeJid(''), null);
  assert.strictEqual(normalizeJid(null), null);
});

test('enqueueSend serializes asynchronous tasks without race conditions', async () => {
  const executionOrder = [];

  const task1 = enqueueSend(async () => {
    await sleep(20);
    executionOrder.push(1);
    return 'result1';
  });

  const task2 = enqueueSend(async () => {
    await sleep(5);
    executionOrder.push(2);
    return 'result2';
  });

  const [res1, res2] = await Promise.all([task1, task2]);

  assert.strictEqual(res1, 'result1');
  assert.strictEqual(res2, 'result2');
  // Task 1 must finish before Task 2 begins, even though Task 2 sleep was shorter
  assert.deepStrictEqual(executionOrder, [1, 2]);
});
