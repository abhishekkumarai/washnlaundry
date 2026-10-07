"use client";

import { useEffect, useRef } from "react";
import Link from "next/link";

const CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID ?? "";
const PORTAL = "https://customer.washnlaundry.com";

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (cfg: { client_id: string; callback: (r: { credential: string }) => void }) => void;
          renderButton: (el: HTMLElement, opts: Record<string, unknown>) => void;
        };
      };
    };
  }
}

export default function LoginPage() {
  const buttonRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!CLIENT_ID || !buttonRef.current) return;
    const el = buttonRef.current;
    const init = () => {
      window.google!.accounts.id.initialize({
        client_id: CLIENT_ID,
        // The ID token goes in the URL fragment: fragments are never sent to a
        // server or written to access logs. The portal reads it once and clears it.
        callback: ({ credential }) => {
          window.location.href = `${PORTAL}/#t=${credential}`;
        },
      });
      window.google!.accounts.id.renderButton(el, { theme: "outline", size: "large", text: "continue_with", width: 300 });
    };
    if (window.google) return init();
    const s = document.createElement("script");
    s.src = "https://accounts.google.com/gsi/client";
    s.async = true;
    s.onload = init;
    document.head.appendChild(s);
  }, []);

  return (
    <div className="min-h-screen bg-[#F8F7F5] text-[#141A24] antialiased">
      <header className="border-b border-[#E4E0D8]">
        <div className="mx-auto flex max-w-[1240px] items-center justify-between px-5 py-4 lg:px-8">
          <Link href="/" className="text-xl font-black tracking-tight text-slate-900">
            Wash<span className="text-[#2563EB]">N</span>Laundry
          </Link>
          <Link href="/" className="text-[13px] font-semibold text-[#64748B] hover:text-[#182C4F]">
            ← Back to site
          </Link>
        </div>
      </header>

      <main className="mx-auto grid max-w-[1240px] gap-12 px-5 py-14 lg:grid-cols-[1fr_1fr] lg:px-8 lg:py-20">
        <section className="max-w-md">
          <h1 className="font-serif text-3xl font-semibold leading-tight text-[#182C4F] sm:text-4xl">
            Log in or sign up
          </h1>
          <p className="mt-3 text-[15px] leading-relaxed text-[#64748B]">
            One button for both. If the store already has your email you&apos;ll land on your orders;
            if not, we&apos;ll ask for your phone number and set you up.
          </p>

          <div className="mt-8 min-h-[44px]">
            {CLIENT_ID ? (
              <div ref={buttonRef} />
            ) : (
              <a href={PORTAL} className="inline-flex rounded-full bg-[#182C4F] px-5 py-2.5 text-[13px] font-semibold text-white hover:bg-[#101E38]">
                Continue to customer portal
              </a>
            )}
          </div>
          <p className="mt-4 text-xs text-[#64748B]">
            We only read your name and verified email from Google. No password is stored.
          </p>
        </section>

        <aside className="border-t border-[#E4E0D8] pt-8 lg:border-l lg:border-t-0 lg:pl-12 lg:pt-0">
          <h2 className="text-xs font-semibold uppercase tracking-widest text-[#64748B]">Once you&apos;re in</h2>
          <ul className="mt-4 divide-y divide-[#E4E0D8] border-y border-[#E4E0D8] text-[15px]">
            <li className="py-3"><span className="font-medium">Track every order</span><span className="block text-sm text-[#64748B]">Placed, processing, ironing, ready, out for delivery.</span></li>
            <li className="py-3"><span className="font-medium">See what&apos;s paid and what&apos;s due</span><span className="block text-sm text-[#64748B]">Line items and totals for each bill.</span></li>
            <li className="py-3"><span className="font-medium">Book a pickup</span><span className="block text-sm text-[#64748B]">We confirm the slot by phone.</span></li>
          </ul>
        </aside>
      </main>
    </div>
  );
}
