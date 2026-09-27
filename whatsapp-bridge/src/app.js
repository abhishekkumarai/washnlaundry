import express from 'express';
import fs from 'fs';
import {
  getConnectionState,
  getCurrentQr,
  getConnectedUser,
  sendTextMessage,
  sendMediaMessage,
  disconnectWhatsApp
} from './socket.js';

const app = express();
const BRIDGE_TOKEN = process.env.BRIDGE_TOKEN || '';
const DEFAULT_COUNTRY_CODE = process.env.DEFAULT_COUNTRY_CODE || '91';

// Large limit to accept base64 invoices/PDFs
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

/**
 * Normalizes phone number or JID to WhatsApp E.164 JID format
 * e.g. "9876543210" -> "919876543210@s.whatsapp.net"
 * e.g. "+91 98765 43210" -> "919876543210@s.whatsapp.net"
 */
export function normalizeJid(input) {
  if (!input) return null;
  const raw = String(input).trim();
  if (raw.endsWith('@s.whatsapp.net') || raw.endsWith('@g.us')) {
    return raw;
  }
  const digitsOnly = raw.replace(/\D/g, '');
  if (!digitsOnly) return null;

  if (digitsOnly.length === 10) {
    return `${DEFAULT_COUNTRY_CODE}${digitsOnly}@s.whatsapp.net`;
  }
  return `${digitsOnly}@s.whatsapp.net`;
}

/**
 * Authentication Middleware: Protects endpoints if BRIDGE_TOKEN is configured
 */
export function authMiddleware(req, res, next) {
  if (!BRIDGE_TOKEN) {
    return next();
  }
  const authHeader = req.headers.authorization;
  const headerToken = req.headers['x-bridge-token'];
  const token = (authHeader && authHeader.startsWith('Bearer '))
    ? authHeader.substring(7)
    : headerToken;

  if (!token || token !== BRIDGE_TOKEN) {
    return res.status(401).json({ ok: false, error: 'Unauthorized: Invalid bridge token' });
  }
  next();
}

// -------------------------------------------------------------
// Routes
// -------------------------------------------------------------

/**
 * GET /health
 * Public health check endpoint for container liveness and frontend status
 */
app.get('/health', (req, res) => {
  const status = getConnectionState();
  const user = getConnectedUser();
  res.json({
    ok: true,
    status, // 'connected' | 'qr_ready' | 'disconnected'
    user,
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString()
  });
});

/**
 * GET /qr
 * Returns current QR code data URL for pairing modal
 */
app.get('/qr', (req, res) => {
  const qrData = getCurrentQr();
  res.json({
    ok: true,
    ...qrData
  });
});

/**
 * POST /send
 * Sends standard text message
 */
app.post('/send', authMiddleware, async (req, res) => {
  try {
    const { chatId, phone, message } = req.body;
    const target = normalizeJid(chatId || phone);

    if (!target) {
      return res.status(400).json({ ok: false, error: 'Missing or invalid chatId/phone' });
    }
    if (!message || typeof message !== 'string' || !message.trim()) {
      return res.status(400).json({ ok: false, error: 'Message cannot be empty' });
    }

    const sent = await sendTextMessage(target, message);
    return res.json({
      ok: true,
      chatId: target,
      messageId: sent?.key?.id || null,
      timestamp: sent?.messageTimestamp || Date.now()
    });
  } catch (err) {
    console.error('Error sending WhatsApp message:', err);
    return res.status(500).json({
      ok: false,
      error: err.message || 'Failed to send message'
    });
  }
});

/**
 * POST /send-media
 * Sends document (PDF receipt), image, or audio
 */
app.post('/send-media', authMiddleware, async (req, res) => {
  try {
    const {
      chatId,
      phone,
      fileBase64,
      filePath,
      fileName = 'receipt.pdf',
      caption = '',
      mimetype = 'application/pdf'
    } = req.body;

    const target = normalizeJid(chatId || phone);
    if (!target) {
      return res.status(400).json({ ok: false, error: 'Missing or invalid chatId/phone' });
    }

    let buffer;
    if (fileBase64) {
      buffer = Buffer.from(fileBase64, 'base64');
    } else if (filePath) {
      if (!fs.existsSync(filePath)) {
        return res.status(404).json({ ok: false, error: `File not found: ${filePath}` });
      }
      buffer = fs.readFileSync(filePath);
    } else {
      return res.status(400).json({ ok: false, error: 'Must provide either fileBase64 or filePath' });
    }

    let mediaPayload;
    if (mimetype.startsWith('image/')) {
      mediaPayload = { image: buffer, caption: caption || undefined };
    } else if (mimetype.startsWith('video/')) {
      mediaPayload = { video: buffer, caption: caption || undefined };
    } else {
      // Default to document (PDF receipts, spreadsheets, etc.)
      mediaPayload = {
        document: buffer,
        fileName,
        mimetype,
        caption: caption || undefined
      };
    }

    const sent = await sendMediaMessage(target, mediaPayload);
    return res.json({
      ok: true,
      chatId: target,
      messageId: sent?.key?.id || null,
      fileName,
      timestamp: sent?.messageTimestamp || Date.now()
    });
  } catch (err) {
    console.error('Error sending WhatsApp media:', err);
    return res.status(500).json({
      ok: false,
      error: err.message || 'Failed to send media'
    });
  }
});

/**
 * POST /disconnect
 * Log out and clear session data
 */
app.post('/disconnect', authMiddleware, async (req, res) => {
  try {
    await disconnectWhatsApp(true);
    return res.json({ ok: true, message: 'Session disconnected and cleared' });
  } catch (err) {
    return res.status(500).json({ ok: false, error: err.message });
  }
});

export default app;
