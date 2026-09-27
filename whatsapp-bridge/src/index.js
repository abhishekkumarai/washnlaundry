import app from './app.js';
import { startWhatsAppSocket, disconnectWhatsApp } from './socket.js';

const PORT = parseInt(process.env.PORT || '3000', 10);

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 [LaundryBill WhatsApp Bridge] Running on port ${PORT}`);
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
