export interface Env {
  BACKEND_ORIGIN: string;
}

// Edge reverse proxy for /api/* -> the Render Django backend. Lets the
// Flutter app call a single origin (app.washnlaundry.com/api/...) with no
// browser CORS roundtrip, while Cloudflare's WAF/Bot Fight Mode/rate
// limiting sit in front of it (configured at the zone level, not here).
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (!url.pathname.startsWith('/api/')) {
      return new Response('Not found', { status: 404 });
    }

    const backendUrl = new URL(url.pathname + url.search, env.BACKEND_ORIGIN);

    const proxied = new Request(backendUrl, {
      method: request.method,
      headers: request.headers,
      body: request.method === 'GET' || request.method === 'HEAD' ? undefined : request.body,
      redirect: 'manual',
    });
    proxied.headers.set('X-Forwarded-Host', url.hostname);
    proxied.headers.set('X-Forwarded-Proto', 'https');

    const response = await fetch(proxied);

    const headers = new Headers(response.headers);
    // Keep the backend's X-Frame-Options and only allow our own sites to frame responses (KAN-195).
    if (!headers.has('X-Frame-Options')) headers.set('X-Frame-Options', 'DENY');
    headers.set(
      'Content-Security-Policy',
      "frame-ancestors 'self' https://app.washnlaundry.com https://customer.washnlaundry.com",
    );

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  },
};
