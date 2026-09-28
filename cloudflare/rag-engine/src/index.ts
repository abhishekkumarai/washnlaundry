export interface Env {
  AI: Ai;
  VECTORIZE: VectorizeIndex;
  KB: KVNamespace;
  BACKEND_ORIGIN: string;
  CORS_ALLOWED_ORIGINS: string;
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

async function callTool(env: Env, name: string, args: Record<string, unknown>): Promise<string> {
  const query = String(args.query ?? '');
  if (name === 'lookup_order') {
    const res = await fetch(`${env.BACKEND_ORIGIN}/api/orders/?search=${encodeURIComponent(query)}`);
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
    const res = await fetch(`${env.BACKEND_ORIGIN}/api/customers/?search=${encodeURIComponent(query)}`);
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

function corsHeaders(env: Env, origin: string | null): HeadersInit {
  const allowed = env.CORS_ALLOWED_ORIGINS.split(',').map((s) => s.trim());
  const allowOrigin = origin && allowed.includes(origin) ? origin : allowed[0];
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await handle(request, env);
    } catch (err: any) {
      return new Response(JSON.stringify({ error: err?.message ?? String(err), stack: err?.stack }), {
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
    if (authHeader !== `Bearer ${env.RAG_API_KEY}`) {
      return new Response('Unauthorized', { status: 401, headers: cors });
    }

    const body = (await request.json()) as {
      message: string;
      history?: { role: 'user' | 'assistant'; content: string }[];
    };
    if (!body.message) {
      return new Response('message is required', { status: 400, headers: cors });
    }

    const contextChunks = await retrieveContext(env, body.message);
    const contextText = contextChunks
      .map((c, i) => `[${i + 1}] (${c.source})\n${c.text}`)
      .join('\n\n');

    if (url.searchParams.get('debug') === 'context') {
      return new Response(JSON.stringify({ contextChunks }, null, 2), {
        headers: { ...cors, 'Content-Type': 'application/json' },
      });
    }

    const systemPrompt = `You are the WashNLaundry customer support assistant. Answer using the
provided knowledge base context and, when the question needs real-time data
(order status, dues), call the appropriate tool rather than guessing.
Always cite context sources as [1], [2], etc. when you use them. If you
don't know, say so honestly — never invent an order status or a price.

Knowledge base context:
${contextText || '(no relevant context found)'}`;

    const messages: any[] = [
      { role: 'system', content: systemPrompt },
      ...(body.history ?? []),
      { role: 'user', content: body.message },
    ];

    // Resolve tool calls first (non-streaming), then stream the final answer.
    for (let round = 0; round < 3; round++) {
      const result = (await env.AI.run(CHAT_MODEL, {
        messages,
        tools: TOOLS as any,
      })) as any;

      // The OpenAI-shaped tool_calls (with id/type/function) are what the
      // API expects back in the next request; result.tool_calls is just a
      // flattened convenience array and isn't valid to echo back as-is.
      const message = result.choices?.[0]?.message;
      const toolCalls = message?.tool_calls ?? [];
      if (url.searchParams.get('debug') === 'tools') {
        return new Response(JSON.stringify({ round, result }, null, 2), {
          headers: { ...cors, 'Content-Type': 'application/json' },
        });
      }
      if (toolCalls.length === 0) {
        break;
      }

      messages.push({ role: 'assistant', content: message.content ?? '', tool_calls: toolCalls });
      for (const call of toolCalls) {
        const args = JSON.parse(call.function.arguments || '{}');
        const toolResult = await callTool(env, call.function.name, args);
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
