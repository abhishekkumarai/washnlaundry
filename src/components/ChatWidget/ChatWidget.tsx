"use client";

import { useState, useRef, useEffect } from "react";
import { Bot, X, Send } from "lucide-react";

// Same Django proxy the Flutter CRM chat uses (backend/api/services/rag_service.py)
// — it attaches the washnlaundry-rag Worker's RAG_API_KEY server-side, which
// must never reach a public JS bundle, and the backend already allows all
// origins (CORS_ALLOW_ALL_ORIGINS), so this site calls it directly with no
// Next.js API route of its own needed.
const RAG_CHAT_URL = "https://laundrybill-backend.onrender.com/api/rag/chat/";

type ChatMessage = {
  role: "user" | "assistant";
  text: string;
};

// Mirrors ApiService.streamRagChat's two-shape SSE tolerance in the Flutter
// app — the worker's streaming response varies by which Workers AI call
// produced it (plain text-generation vs. the OpenAI-style chat delta).
function extractSseToken(decoded: any): string | null {
  if (!decoded || typeof decoded !== "object") return null;
  if (typeof decoded.response === "string") return decoded.response;
  const content = decoded.choices?.[0]?.delta?.content;
  return typeof content === "string" ? content : null;
}

async function* streamRagChat(message: string, history: ChatMessage[]): AsyncGenerator<string> {
  const res = await fetch(RAG_CHAT_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      message,
      history: history.map((m) => ({ role: m.role, content: m.text })),
    }),
  });

  if (!res.ok || !res.body) {
    const body = await res.text().catch(() => "");
    throw new Error(`Assistant is unavailable right now (${res.status}). ${body.slice(0, 150)}`);
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const events = buffer.split("\n\n");
    buffer = events.pop() ?? "";
    for (const event of events) {
      const line = event.trim();
      if (!line.startsWith("data:")) continue;
      const data = line.slice(5).trim();
      if (!data || data === "[DONE]") continue;
      try {
        const token = extractSseToken(JSON.parse(data));
        if (token) yield token;
      } catch {
        // Malformed SSE fragment — skip it rather than break the stream.
      }
    }
  }
}

export default function ChatWidget() {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, open]);

  const send = async () => {
    const text = input.trim();
    if (!text || sending) return;
    setInput("");
    setError(null);

    const history = messages;
    setMessages((prev) => [...prev, { role: "user", text }, { role: "assistant", text: "" }]);
    setSending(true);

    try {
      for await (const token of streamRagChat(text, history)) {
        setMessages((prev) => {
          const next = [...prev];
          next[next.length - 1] = { role: "assistant", text: next[next.length - 1].text + token };
          return next;
        });
      }
    } catch (err: any) {
      setMessages((prev) => {
        const last = prev[prev.length - 1];
        return last?.role === "assistant" && !last.text ? prev.slice(0, -1) : prev;
      });
      setError(err?.message || "Could not reach the assistant.");
    } finally {
      setSending(false);
    }
  };

  return (
    <>
      {open && (
        // Bottom-left, not bottom-right: that corner already stacks the
        // Scroll-to-top / Call / WhatsApp FABs (see page.tsx), and how many
        // of those are visible varies with scroll position, so anchoring
        // here avoids ever overlapping them rather than guessing an offset.
        <div className="fixed bottom-24 left-5 sm:left-6 z-50 w-[calc(100vw-2.5rem)] max-w-[360px] h-[min(560px,calc(100vh-160px))] bg-white rounded-2xl shadow-2xl border border-[#E4E0D8] flex flex-col overflow-hidden">
          <div className="flex items-center gap-2 px-4 py-3 bg-[#182C4F] text-white">
            <Bot size={18} />
            <span className="flex-1 text-sm font-bold tracking-tight">WashNLaundry Assistant</span>
            <button
              onClick={() => setOpen(false)}
              aria-label="Close chat"
              className="p-1 hover:bg-white/10 rounded-full transition-colors cursor-pointer"
            >
              <X size={16} />
            </button>
          </div>

          <div ref={scrollRef} className="flex-1 overflow-y-auto px-3 py-3 space-y-2.5">
            {messages.length === 0 ? (
              <p className="text-center text-sm text-[#64748B] px-4 py-6">
                Ask about pickup &amp; delivery, rates, turnaround time, or store policies.
              </p>
            ) : (
              messages.map((m, i) => (
                <div key={i} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
                  <div
                    className={`max-w-[80%] rounded-xl px-3 py-2 text-sm leading-relaxed whitespace-pre-wrap ${
                      m.role === "user"
                        ? "bg-[#182C4F] text-white"
                        : "bg-[#F0EEE9] text-[#141A24]"
                    }`}
                  >
                    {m.text || "…"}
                  </div>
                </div>
              ))
            )}
            {error && <p className="text-xs text-red-600 px-1">{error}</p>}
          </div>

          <div className="flex items-center gap-2 p-2.5 border-t border-[#E4E0D8]">
            <input
              value={input}
              disabled={sending}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") send();
              }}
              placeholder="Type a message…"
              className="flex-1 text-sm rounded-lg border border-[#E4E0D8] px-3 py-2 outline-none focus:border-[#182C4F] disabled:opacity-60"
            />
            <button
              onClick={send}
              disabled={sending || !input.trim()}
              aria-label="Send"
              className="flex items-center justify-center w-9 h-9 rounded-lg bg-[#182C4F] hover:bg-[#101E38] disabled:bg-[#E4E0D8] disabled:cursor-not-allowed transition-colors cursor-pointer"
            >
              <Send size={15} className="text-white" />
            </button>
          </div>
        </div>
      )}

      <button
        onClick={() => setOpen((v) => !v)}
        aria-label={open ? "Close chat" : "Chat with WashNLaundry Assistant"}
        title="Chat with us"
        className="pointer-events-auto fixed bottom-6 left-5 sm:left-6 z-50 flex items-center justify-center w-13 h-13 rounded-full bg-[#182C4F] hover:bg-[#101E38] text-white shadow-xl hover:shadow-2xl transition-all duration-200 hover:-translate-y-0.5"
      >
        {open ? <X size={20} /> : <Bot size={20} />}
      </button>
    </>
  );
}
