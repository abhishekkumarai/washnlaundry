import app from './app.js';
import { startWhatsAppSocket, disconnectWhatsApp, setIncomingMessageHandler, sendTextMessage } from './socket.js';
import { handleIncomingMessage } from './autoReply.js';

const PORT = parseInt(process.env.PORT || '3000', 10);

// Auto-replying on the real, already-linked WhatsApp session is a production
// behaviour change, not a contained addition — off by default, opt in
// explicitly once the RAG backend is verified working.
const AUTO_REPLY_ENABLED = (process.env.AUTO_REPLY_ENABLED || 'false').toLowerCase() === 'true';
const BACKEND_URL = process.env.BACKEND_URL || 'http://127.0.0.1:8000';
const RAG_WORKER_URL = process.env.RAG_WORKER_URL || 'https://washnlaundry-rag.abhishekkumarai.workers.dev';
const RAG_API_KEY = process.env.RAG_API_KEY || '';

setIncomingMessageHandler((message) =>
  handleIncomingMessage(message, {
    enabled: AUTO_REPLY_ENABLED,
    backendUrl: BACKEND_URL,
    ragWorkerUrl: RAG_WORKER_URL,
    ragApiKey: RAG_API_KEY,
    sendTextMessage,
    logger: console,
  })
);

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 [LaundryBill WhatsApp Bridge] Running on port ${PORT}`);
  console.log(`   RAG auto-reply: ${AUTO_REPLY_ENABLED ? `ENABLED (${RAG_WORKER_URL})` : 'disabled'}`);
  startWhatsAppSocket();
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('Shutting down WhatsApp Bridge...');
  await disconnectWhatsApp(false);
  server.close(() => process.exit(0));
});

process.on('SIGINT', async () => {
  console.log('Interrupted WhatsApp Bridge...');
  await disconnectWhatsApp(false);
  server.close(() => process.exit(0));
});
