import type { NextRequest } from 'next/server';

const SELF_ORIGIN = 'https://customer.washnlaundry.com';

// Only the customer-scoped endpoints and the public pickup form are reachable;
// the rest of the backend API (which is unauthenticated) must never be proxied.
const ALLOWED = [/^customer\/(me|orders|rate-card)\/?$/, /^customer\/orders\/[\w-]+\/?$/, /^leads\/public\/?$/];

async function proxy(req: NextRequest, ctx: { params: Promise<{ path: string[] }> }) {
  const path = (await ctx.params).path.join('/');
  if (!ALLOWED.some((re) => re.test(path))) {
    return Response.json({ detail: 'Not found.' }, { status: 404 });
  }
  const backend = process.env.BACKEND_ORIGIN ?? 'https://washnlaundry-backend.onrender.com';
  // The backend's public-lead endpoint checks Origin; a Worker-to-Render call has none.
  const headers: Record<string, string> = { Origin: SELF_ORIGIN };
  const auth = req.headers.get('authorization');
  if (auth) headers.Authorization = auth;
  const type = req.headers.get('content-type');
  if (type) headers['Content-Type'] = type;

  let upstream: Response;
  try {
    upstream = await fetch(`${backend}/api/${path.replace(/\/?$/, '/')}`, {
      method: req.method,
      headers,
      body: req.method === 'GET' ? undefined : await req.text(),
      cache: 'no-store',
    });
  } catch {
    return Response.json({ detail: 'The service is waking up. Please try again in a moment.' }, { status: 502 });
  }
  return new Response(upstream.body, {
    status: upstream.status,
    headers: { 'Content-Type': upstream.headers.get('content-type') ?? 'application/json' },
  });
}

export { proxy as GET, proxy as POST };
