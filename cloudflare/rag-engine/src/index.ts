export interface Env {
  AI: Ai;
  VECTORIZE: VectorizeIndex;
  KB: KVNamespace;
  BACKEND_ORIGIN: string;
  CORS_ALLOWED_ORIGINS: string;
  BOOKING_ORIGINS: string;
  RAG_API_KEY: string;
}

const EMBEDDING_MODEL = '@cf/baai/bge-base-en-v1.5';
const CHAT_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';

const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'lookup_order',
      description:
        "Look up one or more orders by order number, customer name, or phone number. Use this whenever the customer asks about order status, ready date, or where their order is.",
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Order number, customer name, or phone number.' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'lookup_customer_dues',
      description:
        'Look up a customer by phone number or name and return their outstanding dues (unpaid/partial balance).',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Customer phone number or name.' },
        },
        required: ['query'],
      },
    },
  },
] as const;

// Marketing-site only: hands a completed pickup request to the backend, which
// saves it as a Lead and emails the shop. Kept out of TOOLS so the
// staff/support channel can never trigger outbound messages.
const BOOKING_TOOL = {
  type: 'function',
  function: {
    name: 'submit_booking',
    description:
      'Submit a pickup request. Call this ONLY once the customer has given ALL of: name, 10-digit mobile number, pickup address, and laundry requirements. Do not call it twice for the same customer.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: "Customer's name." },
        phone: { type: 'string', description: '10-digit Indian mobile number.' },
        address: { type: 'string', description: 'Pickup address / locality.' },
        requirements: {
          type: 'string',
          description: 'Service type, approximate garment count, preferred pickup day/time.',
        },
      },
      required: ['name', 'phone', 'address', 'requirements'],
    },
  },
} as const;

// Text the assistant is told to include after a successful booking; used to
// refuse a second submission within the same conversation.
const BOOKING_SENT_MARKER = 'pickup request has been sent';

async function submitBooking(
  env: Env,
  args: Record<string, unknown>,
  alreadyBooked: boolean,
): Promise<string> {
  if (alreadyBooked) {
    return JSON.stringify({ ok: false, error: 'A booking was already submitted in this conversation.' });
  }
  const phone = String(args.phone ?? '').replace(/\D/g, '').replace(/^(91|0)(?=\d{10}$)/, '');
  if (!/^[6-9]\d{9}$/.test(phone)) {
    return JSON.stringify({ ok: false, error: 'invalid_phone: ask the customer for a valid 10-digit mobile number.' });
  }
  try {
    const res = await fetch(`${env.BACKEND_ORIGIN}/api/leads/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${env.RAG_API_KEY}` },
      body: JSON.stringify({
        name: String(args.name ?? ''),
        phone,
        address: String(args.address ?? ''),
        requirements: String(args.requirements ?? ''),
      }),
      signal: AbortSignal.timeout(25000),
    });
    if (!res.ok) return JSON.stringify({ ok: false, error: `backend returned ${res.status}` });
    return JSON.stringify({ ok: true });
  } catch (err: any) {
    return JSON.stringify({ ok: false, error: `Booking failed: ${err?.message ?? err}` });
  }
}

async function callTool(
  env: Env,
  name: string,
  args: Record<string, unknown>,
  ctx: { alreadyBooked: boolean } = { alreadyBooked: false },
): Promise<string> {
  const query = String(args.query ?? '');
  try {
    if (name === 'submit_booking') return await submitBooking(env, args, ctx.alreadyBooked);
    if (name === 'lookup_order') {
      const res = await fetch(`${env.BACKEND_ORIGIN}/api/orders/?search=${encodeURIComponent(query)}`, {
        signal: AbortSignal.timeout(10000),
      });
      if (!res.ok) return JSON.stringify({ error: `backend returned ${res.status}` });
      const data = (await res.json()) as any[];
      const summary = data.slice(0, 5).map((o) => ({
        order_number: o.order_number,
        status: o.status,
        payment_status: o.payment_status,
        total_amount: o.total_amount,
        due_amount: o.due_amount,
        customer_name: o.customer_name,
      }));
      return JSON.stringify({ orders: summary, count: data.length });
    }
    if (name === 'lookup_customer_dues') {
      const res = await fetch(`${env.BACKEND_ORIGIN}/api/customers/?search=${encodeURIComponent(query)}`, {
        signal: AbortSignal.timeout(10000),
      });
      if (!res.ok) return JSON.stringify({ error: `backend returned ${res.status}` });
      const data = (await res.json()) as any[];
      const summary = data.slice(0, 5).map((c) => ({
        name: c.name,
        phone: c.phone,
        due_amount: c.due_amount,
      }));
      return JSON.stringify({ customers: summary, count: data.length });
    }
    return JSON.stringify({ error: `unknown tool ${name}` });
  } catch (err: any) {
    return JSON.stringify({ error: `Tool execution failed: ${err?.message ?? err}` });
  }
}

async function retrieveContext(env: Env, query: string) {
  const embedding = (await env.AI.run(EMBEDDING_MODEL, { text: [query] })) as { data: number[][] };
  const vector = embedding.data[0];
  const matches = await env.VECTORIZE.query(vector, { topK: 4, returnMetadata: 'all' });

  const chunks: { id: string; source: string; text: string; score: number }[] = [];
  for (const m of matches.matches) {
    const text = (m.metadata?.text as string) ?? (await env.KB.get(m.id)) ?? '';
    if (!text) continue;
    chunks.push({
      id: m.id,
      source: (m.metadata?.source as string) ?? m.id,
      text,
      score: m.score,
    });
  }
  return chunks;
}

function isOriginAllowed(env: Env, origin: string | null): boolean {
  if (!origin) return false;
  const allowed = env.CORS_ALLOWED_ORIGINS.split(',').map((s) => s.trim().toLowerCase());
  const originLower = origin.toLowerCase();
  if (allowed.includes(originLower)) return true;
  // Allow localhost / 127.0.0.1 for local dev across any port
  if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(originLower)) return true;
  return false;
}

function corsHeaders(env: Env, origin: string | null): HeadersInit {
  const allowed = env.CORS_ALLOWED_ORIGINS.split(',').map((s) => s.trim());
  const allowOrigin = isOriginAllowed(env, origin) && origin ? origin : allowed[0];
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}

export default {
  // Cron (every 15 min, see wrangler.jsonc): retry lead emails that failed and
  // keep the free-tier backend awake. Failures are logged, not thrown, so one
  // bad tick can't disable the schedule.
  async scheduled(_event: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(
      (async () => {
        try {
          const res = await fetch(`${env.BACKEND_ORIGIN}/api/leads/process/`, {
            method: 'POST',
            headers: { Authorization: `Bearer ${env.RAG_API_KEY}` },
            signal: AbortSignal.timeout(60000),
          });
          console.log(`lead cron: ${res.status} ${await res.text()}`);
        } catch (err: any) {
          console.error(`lead cron failed: ${err?.message ?? err}`);
        }
      })(),
    );
  },

  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await handle(request, env);
    } catch (err: any) {
      return new Response(JSON.stringify({ error: 'Internal error' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }
  },
};

async function handle(request: Request, env: Env): Promise<Response> {
  {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin');
    const cors = corsHeaders(env, origin);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: cors });
    }

    if (url.pathname !== '/api/rag/chat' || request.method !== 'POST') {
      return new Response('Not found', { status: 404, headers: cors });
    }

    const authHeader = request.headers.get('Authorization');
    const hasValidKey = authHeader === `Bearer ${env.RAG_API_KEY}`;
    const hasAllowedOrigin = isOriginAllowed(env, origin);

    if (!hasValidKey && !hasAllowedOrigin) {
      return new Response('Unauthorized', { status: 401, headers: cors });
    }

    const body = (await request.json()) as {
      message: string;
      history?: { role: 'user' | 'assistant'; content: string }[];
      channel?: string;
    };
    if (!body.message) {
      return new Response('message is required', { status: 400, headers: cors });
    }

    // Lead capture is exclusive to the marketing site: an exact Origin match,
    // not the spoofable body.channel, so the CRM or any other allowed origin
    // can never submit bookings or trigger lead emails.
    const canBook = origin
      ? env.BOOKING_ORIGINS.split(',').some((o) => o.trim().toLowerCase() === origin.toLowerCase())
      : false;

    const isMarketing =
      body.channel === 'marketing' || (origin ? origin.includes('washnlaundry-marketing') : false);

    const contextChunks = await retrieveContext(env, body.message);
    const contextText = contextChunks
      .map((c, i) => `[${i + 1}] (${c.source})\n${c.text}`)
      .join('\n\n');

    if (url.searchParams.get('debug') === 'context' && hasValidKey) {
      return new Response(JSON.stringify({ contextChunks }, null, 2), {
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const SHOP_WHATSAPP_NUMBER = '917277905904';

    const systemPrompt = isMarketing
      ? `You are the friendly WashNLaundry customer booking & support assistant on our official website (washnlaundry.com).

CORE OPERATIONAL RULES:
1. STRICT TOPIC RESTRICTION: You ONLY assist with WashNLaundry services and laundry-related queries — services offered (Wash & Fold, Wash & Iron, Steam Ironing, Dry Cleaning, Shoe Cleaning, Premium Fabric Care), rates and pricing, turnaround time, pickup & delivery slots, and fabric care policies.
   - If a visitor asks about ANY unrelated topic (coding, software, math, politics, general trivia, writing essays/scripts, unrelated companies), STRICTLY and POLITELY refuse to answer: "I can only assist with WashNLaundry services, pricing, and scheduling laundry pickups. How can I help you with your laundry today?" DO NOT answer the unrelated question under any circumstances.
2. ANSWER CONCISELY: Keep your service/pricing answers brief and friendly (1 to 2 short paragraphs max).
3. PROACTIVE LEAD & BOOKING INTAKE:
   Whenever a visitor asks about laundry, prices, or express delivery, your primary objective is to help them schedule a pickup by collecting their details:
   - 1. Customer's Name
   - 2. Mobile Phone Number (10 digits)
   - 3. Pickup Address / Locality
   - 4. Laundry Requirements (e.g. service type, estimated garment count, preferred pickup day/time)
4. CONVERSATIONAL INTAKE STEPS:
   - Check the prior conversation history to see which of the 4 details have already been provided.
   - Answer their inquiry first, then naturally ask for whatever details are still missing (e.g. "Would you like me to arrange a pickup for you? May I know your name and mobile number to get started?").
   - If they provide partial details, warmly acknowledge them and ask for the remainder (e.g. "Thanks [Name]! Could you also share your pickup address and what items you need cleaned?").
${canBook ? `   - Once ALL 4 details (Name, Phone, Address, Requirements) are collected, call the submit_booking tool exactly once. Never invent or print any link — the team is notified automatically.
   - If submit_booking returns ok, reply with a short confirmation summarising the 4 details and include the exact phrase "Your pickup request has been sent" followed by "to our team — we will call you shortly to confirm your pickup slot."
   - If it returns an error mentioning the phone number, ask for a valid 10-digit mobile number. For any other error, apologise and ask the customer to try again in a minute or call the shop.` : `   - You cannot take bookings in this chat. If they want a pickup, politely ask them to contact the shop directly.`}

Knowledge base context:
${contextText || '(no relevant context found)'}`
      : `You are the WashNLaundry customer support assistant. Answer using the
provided knowledge base context and, when the question needs real-time data
(order status, dues), call the appropriate tool rather than guessing.
Always cite context sources as [1], [2], etc. when you use them. If you
don't know, say so honestly — never invent an order status or a price.

Knowledge base context:
${contextText || '(no relevant context found)'}`;

    // Clients may only supply user/assistant turns (never system/tool), capped
    // in count and size so a caller can't override the prompt or inflate cost.
    const history = (Array.isArray(body.history) ? body.history : [])
      .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string')
      .slice(-20)
      .map((m) => ({ role: m.role, content: m.content.slice(0, 2000) }));

    const messages: any[] = [
      { role: 'system', content: systemPrompt },
      ...history,
      { role: 'user', content: body.message.slice(0, 2000) },
    ];

    const alreadyBooked = history.some(
      (m) => m.role === 'assistant' && m.content.toLowerCase().includes(BOOKING_SENT_MARKER),
    );

    // The public marketing site gets no order/dues lookups (they would expose
    // customer data to anyone); it can only submit a booking.
    const activeTools = isMarketing ? (canBook ? [BOOKING_TOOL] : []) : TOOLS;

    // Resolve tool calls first (non-streaming), then stream the final answer.
    for (let round = 0; round < 3; round++) {
      const result = (await env.AI.run(CHAT_MODEL, {
        messages,
        // Workers AI rejects an empty tools array, so omit the key entirely.
        ...(activeTools.length ? { tools: activeTools as any } : {}),
      })) as any;

      // The OpenAI-shaped tool_calls (with id/type/function) are what the
      // API expects back in the next request; result.tool_calls is just a
      // flattened convenience array and isn't valid to echo back as-is.
      const message = result.choices?.[0]?.message;
      const toolCalls = message?.tool_calls ?? [];
      if (url.searchParams.get('debug') === 'tools' && hasValidKey) {
        return new Response(JSON.stringify({ round, result }, null, 2), {
          headers: { ...cors, 'Content-Type': 'application/json' },
        });
      }
      if (toolCalls.length === 0) {
        break;
      }

      messages.push({ role: 'assistant', content: message.content ?? '', tool_calls: toolCalls });
      for (const call of toolCalls) {
        let args: Record<string, unknown> = {};
        try {
          args = JSON.parse(call.function.arguments || '{}');
        } catch {
          // Malformed model output: let the tool report missing fields instead of 500ing.
        }
        const toolResult = await callTool(env, call.function.name, args, { alreadyBooked });
        messages.push({ role: 'tool', tool_call_id: call.id, content: toolResult });
      }
    }

    const stream = (await env.AI.run(CHAT_MODEL, {
      messages,
      stream: true,
    })) as ReadableStream;

    return new Response(stream, {
      headers: {
        ...cors,
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
      },
    });
  }
}
