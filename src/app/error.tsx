'use client';

import { useEffect } from 'react';
import Link from 'next/link';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Log unexpected errors securely without exposing details to UI
    console.error('Unhandled Next.js application error:', error);
  }, [error]);

  return (
    <div className="min-h-screen bg-[#F8F7F5] text-[#141A24] flex flex-col antialiased selection:bg-[#182C4F] selection:text-white">
      {/* Header */}
      <header className="border-b border-[#E4E0D8] bg-[#F8F7F5]/90 backdrop-blur-md">
        <div className="mx-auto flex max-w-[1240px] items-center justify-between px-5 py-4 lg:px-8">
          <Link href="/" className="flex items-center gap-3 group">
            <img
              src="/brand-logo.png"
              alt="WashNLaundry Logo"
              className="h-12 w-12 object-contain rounded-full border border-[#E4E0D8] bg-white p-1"
            />
            <span className="text-xl font-black tracking-tight text-slate-900">
              Wash<span className="text-[#2563EB]">N</span>Laundry
            </span>
          </Link>
          <Link
            href="/"
            className="text-xs font-semibold text-slate-600 hover:text-slate-900 transition-colors"
          >
            ← Back to Home
          </Link>
        </div>
      </header>

      {/* Main 500 Content */}
      <main className="flex-1 flex items-center justify-center px-4 py-16">
        <div className="w-full max-w-lg text-center bg-white border border-[#E4E0D8] rounded-2xl p-8 sm:p-12 shadow-sm">
          <div className="mx-auto w-16 h-16 rounded-full bg-rose-50 flex items-center justify-center text-rose-500 mb-6">
            <svg
              className="w-8 h-8"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
              />
            </svg>
          </div>

          <span className="inline-block px-3 py-1 text-xs font-bold uppercase tracking-wider text-rose-600 bg-rose-50 rounded-full mb-3">
            Error 500
          </span>

          <h1 className="text-2xl sm:text-3xl font-extrabold text-[#141A24] tracking-tight">
            Something Went Wrong
          </h1>

          <p className="mt-3 text-sm text-[#64748B] leading-relaxed max-w-md mx-auto">
            Our server encountered an issue while processing your request. Please try again shortly.
          </p>

          <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3">
            <button
              onClick={() => reset()}
              className="w-full sm:w-auto inline-flex items-center justify-center px-6 py-2.5 rounded-lg bg-[#182C4F] text-white text-xs font-bold shadow-sm hover:bg-[#101E38] transition-colors cursor-pointer"
            >
              Try Again
            </button>
            <Link
              href="/"
              className="w-full sm:w-auto inline-flex items-center justify-center px-6 py-2.5 rounded-lg border border-[#E4E0D8] bg-white text-[#141A24] text-xs font-bold hover:bg-slate-50 transition-colors"
            >
              Return to Home
            </Link>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-[#E4E0D8] bg-[#F8F7F5] py-6 text-center text-xs text-slate-500">
        <p>© 2026 WashNLaundry. Eco-Care Garment Specialists.</p>
      </footer>
    </div>
  );
}
