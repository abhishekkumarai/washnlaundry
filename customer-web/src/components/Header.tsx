'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '@/lib/auth';

const LINKS = [
  { href: '/orders', label: 'Orders' },
  { href: '/rate-card', label: 'Rate card' },
  { href: '/book', label: 'Book pickup' },
];

export function Header() {
  const { profile, signOut } = useAuth();
  const path = usePathname();

  return (
    <header className="border-b border-border">
      <div className="mx-auto flex w-full max-w-3xl items-center justify-between gap-4 px-4 py-4 sm:px-6">
        <Link href="/" className="font-serif text-lg font-semibold text-primary">
          WashNLaundry
        </Link>
        <nav className="flex items-center gap-4 text-sm sm:gap-6">
          {LINKS.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={path.startsWith(l.href) ? 'font-medium text-foreground underline underline-offset-4' : 'text-muted hover:text-foreground'}
            >
              {l.label}
            </Link>
          ))}
          {profile && (
            <button onClick={signOut} className="text-muted hover:text-foreground" title={profile.email}>
              Sign out
            </button>
          )}
        </nav>
      </div>
    </header>
  );
}
