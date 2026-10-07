'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth';
import { GoogleButton } from '@/components/SignInGate';

export default function Home() {
  const { token, ready } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (ready && token) router.replace('/orders');
  }, [ready, token, router]);

  return (
    <div className="grid gap-10 sm:grid-cols-[1.2fr_1fr]">
      <section>
        <h1 className="font-serif text-3xl font-semibold leading-tight text-primary">
          Your laundry, from pickup to doorstep.
        </h1>
        <p className="mt-3 max-w-md text-sm leading-relaxed text-muted">
          Sign in with the Google account you gave the store. You&apos;ll see each order&apos;s stage,
          what&apos;s paid and what&apos;s due. New here? Signing in once creates your account.
        </p>
        <div className="mt-6"><GoogleButton /></div>
      </section>

      <aside className="border-t border-border pt-6 sm:border-l sm:border-t-0 sm:pl-8 sm:pt-0">
        <h2 className="text-xs font-medium uppercase tracking-widest text-muted">Without signing in</h2>
        <ul className="mt-3 space-y-3 text-sm">
          <li><Link href="/rate-card" className="font-medium text-accent hover:underline">See the rate card</Link>
            <p className="text-muted">Per-piece and per-kg prices.</p></li>
          <li><Link href="/book" className="font-medium text-accent hover:underline">Book a pickup</Link>
            <p className="text-muted">We&apos;ll call you to confirm the slot.</p></li>
        </ul>
      </aside>
    </div>
  );
}
