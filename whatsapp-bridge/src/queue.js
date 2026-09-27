/**
 * Queue and Concurrency Safeguards for WhatsApp Bridge
 * Derived from Hermes Agent WhatsApp Bridge architecture.
 */

let _sendQueue = Promise.resolve();

/**
 * Enqueue a task sequentially to prevent overlapping sendMessage() calls
 * on the Baileys WebSocket connection.
 * @param {() => Promise<any>} fn
 * @returns {Promise<any>}
 */
export function enqueueSend(fn) {
  const task = _sendQueue.then(() => fn(), () => fn());
  _sendQueue = task.catch(() => {});
  return task;
}

/**
 * Sleep helper
 * @param {number} ms
 * @returns {Promise<void>}
 */
export function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Executes a send action with an enforced timeout and serialized queue.
 * Prevents hanging sockets from blocking Node.js event loop or starving backend workers.
 *
 * @param {() => Promise<any>} sendFn
 * @param {number} timeoutMs (default 60000ms)
 * @returns {Promise<any>}
 */
export function sendWithTimeout(sendFn, timeoutMs = 60000) {
  let timer;
  const timeoutPromise = new Promise((_, reject) => {
    timer = setTimeout(
      () => reject(new Error(`WhatsApp send operation timed out after ${timeoutMs / 1000}s`)),
      timeoutMs
    );
  });

  return enqueueSend(() =>
    Promise.race([sendFn(), timeoutPromise])
      .finally(() => clearTimeout(timer))
  );
}
