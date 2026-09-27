import {
  makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion
} from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import pino from 'pino';
import path from 'path';
import fs from 'fs';
import qrcodeTerminal from 'qrcode-terminal';
import QRCode from 'qrcode';
import { sendWithTimeout, sleep } from './queue.js';

const logger = pino({ level: process.env.LOG_LEVEL || 'warn' });
const SESSION_DIR = process.env.SESSION_DIR || path.resolve(process.cwd(), 'session');

let sock = null;
let connectionState = 'disconnected'; // 'disconnected' | 'qr_ready' | 'connected'
let currentQr = null;
let currentQrDataUrl = null;
let reconnectTimer = null;
let reconnectAttempts = 0;

// Ensure session directory exists
if (!fs.existsSync(SESSION_DIR)) {
  fs.mkdirSync(SESSION_DIR, { recursive: true });
}

export function getConnectionState() {
  return connectionState;
}

export function getCurrentQr() {
  return {
    qr: currentQr,
    qr_data_url: currentQrDataUrl,
    status: connectionState
  };
}

export function getConnectedUser() {
  if (!sock?.user) return null;
  return {
    id: sock.user.id || null,
    name: sock.user.name || sock.user.verifiedName || null
  };
}

export function getSocket() {
  return sock;
}

function scheduleReconnect(delayMs) {
  if (reconnectTimer) clearTimeout(reconnectTimer);
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    startWhatsAppSocket();
  }, delayMs);
}

export async function startWhatsAppSocket() {
  try {
    const { state, saveCreds } = await useMultiFileAuthState(SESSION_DIR);
    let version;
    try {
      const v = await fetchLatestBaileysVersion();
      version = v.version;
    } catch (err) {
      logger.warn({ err }, 'Failed to fetch latest Baileys version, using default');
    }

    sock = makeWASocket({
      ...(version ? { version } : {}),
      auth: state,
      logger,
      printQRInTerminal: false,
      browser: ['LaundryBill CRM', 'Chrome', '124.0.0'],
      syncFullHistory: false,
      markOnlineOnConnect: false,
      getMessage: async () => ({ conversation: '' })
    });

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', async (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (qr) {
        currentQr = qr;
        connectionState = 'qr_ready';
        try {
          currentQrDataUrl = await QRCode.toDataURL(qr, { margin: 2, scale: 6 });
        } catch (qrErr) {
          logger.error({ qrErr }, 'Failed to generate QR Data URL');
        }

        console.log('\n========================================');
        console.log('🧺 [LaundryBill WhatsApp Bridge] Scan QR:');
        console.log('========================================\n');
        qrcodeTerminal.generate(qr, { small: true });
        console.log('\nWaiting for scan in WhatsApp -> Linked Devices...\n');
      }

      if (connection === 'open') {
        connectionState = 'connected';
        currentQr = null;
        currentQrDataUrl = null;
        reconnectAttempts = 0;
        console.log(`✅ [LaundryBill WhatsApp Bridge] Connected successfully! Logged in as: ${sock.user?.id || 'Unknown'}`);
      }

      if (connection === 'close') {
        const statusCode = new Boom(lastDisconnect?.error)?.output?.statusCode;
        connectionState = 'disconnected';
        console.log(`⚠️ [LaundryBill WhatsApp Bridge] Connection closed. Status Code: ${statusCode}`);

        if (statusCode === DisconnectReason.loggedOut) {
          console.log('❌ WhatsApp session logged out. Clearing session directory for re-pairing.');
          try {
            fs.rmSync(SESSION_DIR, { recursive: true, force: true });
            fs.mkdirSync(SESSION_DIR, { recursive: true });
          } catch (e) {
            logger.error({ e }, 'Error clearing session dir');
          }
          currentQr = null;
          currentQrDataUrl = null;
          scheduleReconnect(3000);
        } else if (statusCode === 515) {
          // 515 = restart required (frequent right after initial QR pairing)
          console.log('↻ WhatsApp requested restart (code 515). Reconnecting in 1s...');
          scheduleReconnect(1000);
        } else {
          reconnectAttempts += 1;
          const delay = Math.min(30000, 2000 * Math.pow(1.5, Math.min(reconnectAttempts, 6)));
          console.log(`↻ Reconnecting in ${(delay / 1000).toFixed(1)}s (Attempt #${reconnectAttempts})...`);
          scheduleReconnect(delay);
        }
      }
    });

    return sock;
  } catch (err) {
    logger.error({ err }, 'Error initializing WhatsApp socket');
    connectionState = 'disconnected';
    scheduleReconnect(5000);
    return null;
  }
}

/**
 * Disconnect socket and optionally wipe session
 */
export async function disconnectWhatsApp(wipeSession = true) {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
  if (sock) {
    try {
      sock.end(undefined);
    } catch (_) {}
    sock = null;
  }
  connectionState = 'disconnected';
  currentQr = null;
  currentQrDataUrl = null;
  if (wipeSession) {
    try {
      fs.rmSync(SESSION_DIR, { recursive: true, force: true });
      fs.mkdirSync(SESSION_DIR, { recursive: true });
    } catch (e) {
      logger.error({ e }, 'Error wiping session');
    }
  }
}

/**
 * Send a text message using the serialized queue and timeout
 */
export async function sendTextMessage(chatId, text, options = {}) {
  if (!sock || connectionState !== 'connected') {
    throw new Error('WhatsApp bridge is not connected');
  }
  return sendWithTimeout(async () => {
    return await sock.sendMessage(chatId, { text }, options);
  });
}

/**
 * Send media message (document, image, video) using serialized queue and timeout
 */
export async function sendMediaMessage(chatId, mediaPayload, options = {}) {
  if (!sock || connectionState !== 'connected') {
    throw new Error('WhatsApp bridge is not connected');
  }
  return sendWithTimeout(async () => {
    return await sock.sendMessage(chatId, mediaPayload, options);
  });
}
