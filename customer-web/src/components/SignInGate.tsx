'use client';

import { useEffect, useRef } from 'react';
import { googleConfigured, mountGoogleButton } from '@/lib/auth';

export function GoogleButton() {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (ref.current && googleConfigured) mountGoogleButton(ref.current);
  }, []);
  if (!googleConfigured) {
    return <p className="text-sm text-danger">Google sign-in isn&apos;t configured on this deployment.</p>;
  }
  return <div ref={ref} className="min-h-[44px]" />;
}

/** Shown in place of a page that needs a signed-in customer. */
export function SignInGate({ why }: { why: string }) {
  return (
    <section className="max-w-md">
      <h1 className="font-serif text-2xl font-semibold text-primary">Sign in to continue</h1>
      <p className="mt-2 text-sm text-muted">{why}</p>
      <div className="mt-5"><GoogleButton /></div>
    </section>
  );
}
