"use client";

import { useState, useRef, useEffect } from "react";
import { Bot, X, Send } from "lucide-react";

// Points directly to the washnlaundry-rag Cloudflare Worker (KAN-112).
// Calling the worker directly avoids proxying long-lived SSE streams through
// Render's single-worker backend, eliminating request deadlocks on tool calls.
const RAG_CHAT_URL = "https://washnlaundry-rag.abhishekkumarai.workers.dev/api/rag/chat";

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
      channel: "marketing",
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

function renderMessageContent(content: string) {
  const linkRegex = /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|(https?:\/\/[^\s]+)/g;
  const parts: (string | React.ReactNode)[] = [];
  let lastIndex = 0;
  let match;

  while ((match = linkRegex.exec(content)) !== null) {
    if (match.index > lastIndex) {
      parts.push(content.substring(lastIndex, match.index));
    }

    const label = match[1] || match[3];
    const url = match[2] || match[3];
    const isWhatsApp = url.includes("wa.me") || url.includes("whatsapp.com");

    if (isWhatsApp) {
      let targetWhatsAppUrl = "https://wa.me/917277905904";
      const summaryMatch = content.match(/•\s*Name[\s\S]*?(?=👉|\[📲|$)/i);
      if (summaryMatch) {
        const cleanSummary = "🧺 *New WashNLaundry Pickup Request*\n" + summaryMatch[0].trim();
        targetWhatsAppUrl += `?text=${encodeURIComponent(cleanSummary)}`;
      } else {
        targetWhatsAppUrl += `?text=${encodeURIComponent("Hello WashNLaundry, I would like to schedule a laundry pickup.")}`;
      }

      parts.push(
        <a
          key={match.index}
          href={targetWhatsAppUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 px-4 py-2.5 my-2 bg-[#25D366] hover:bg-[#20BD5A] text-white font-bold rounded-xl text-xs shadow-md hover:shadow-lg transition-all cursor-pointer no-underline block w-fit"
        >
          <svg className="w-4 h-4 fill-current shrink-0" viewBox="0 0 24 24">
            <path d="M12.031 6.172c-3.181 0-5.767 2.586-5.768 5.766-.001 1.298.38 2.27 1.019 3.287l-.582 2.128 2.182-.573c.978.58 1.911.928 3.145.929 3.178 0 5.767-2.587 5.768-5.766.001-3.187-2.575-5.77-5.764-5.771zm3.392 8.244c-.144.405-.837.774-1.17.824-.312.045-.634.075-1.92-.457-1.554-.641-2.535-2.227-2.613-2.331-.077-.104-.633-.843-.633-1.609 0-.766.401-1.144.543-1.298.143-.154.312-.193.416-.193.104 0 .208.001.299.006.096.005.224-.036.35.267.129.312.441 1.076.48 1.155.039.078.065.17.013.273-.052.104-.078.169-.156.26-.078.091-.164.204-.234.273-.078.078-.16.163-.069.319.091.156.404.667.868 1.08 1.05.934 1.701 1.076 1.944 1.189.243.113.386.095.53-.069.144-.165.617-.718.781-.965.165-.247.33-.206.554-.124.225.082 1.428.673 1.674.796.246.123.41.185.47.288.06.103.06.598-.084 1.003z"/>
          </svg>
          <span>{label.replace(/^\[?📲?\s*/, "") || "Confirm on WhatsApp"}</span>
        </a>
      );
    } else {
      parts.push(
        <a
          key={match.index}
          href={url}
          target="_blank"
          rel="noopener noreferrer"
          className="text-blue-600 underline hover:text-blue-800"
        >
          {label}
        </a>
      );
    }
    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < content.length) {
    parts.push(content.substring(lastIndex));
  }

  return parts;
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
              <div className="text-center py-6 px-3 space-y-3">
                <p className="text-xs font-medium text-[#64748B]">
                  👋 Welcome to WashNLaundry! Ask about our services or schedule a doorstep pickup:
                </p>
                <div className="flex flex-col gap-1.5 pt-1">
                  {[
                    "🧺 I want to schedule a laundry pickup",
                    "💰 What are your wash & iron rates?",
                    "⏱️ What is your turnaround time?",
                  ].map((chip) => (
                    <button
                      key={chip}
                      type="button"
                      onClick={() => {
                        setInput(chip);
                      }}
                      className="text-left text-xs bg-[#F7F5F0] hover:bg-[#EFECE4] text-[#182C4F] font-medium px-3 py-2 rounded-lg border border-[#E4E0D8] transition-colors cursor-pointer"
                    >
                      {chip}
                    </button>
                  ))}
                </div>
              </div>
            ) : (
              messages.map((m, i) => (
                <div key={i} className={`flex ${m.role === "user" ? "justify-end" : "justify-start"}`}>
                  <div
                    className={`max-w-[85%] rounded-xl px-3 py-2 text-sm leading-relaxed whitespace-pre-wrap ${
                      m.role === "user"
                        ? "bg-[#182C4F] text-white"
                        : "bg-[#F0EEE9] text-[#141A24]"
                    }`}
                  >
                    {m.role === "user" ? m.text : renderMessageContent(m.text || "…")}
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
