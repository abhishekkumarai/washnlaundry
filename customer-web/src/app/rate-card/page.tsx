'use client';

import { useEffect, useState } from 'react';
import { api, inr, RateCard } from '@/lib/api';

const UNIT: Record<string, string> = { PIECE: 'piece', KG: 'kg' };

export default function RateCardPage() {
  const [card, setCard] = useState<RateCard | null>(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    api<RateCard>('customer/rate-card/').then(setCard).catch(() => setError(true));
  }, []);

  return (
    <div>
      <h1 className="font-serif text-2xl font-semibold text-primary">Rate card</h1>
      <p className="mt-1 text-sm text-muted">Current prices. Express and delivery charges are added at billing.</p>
      {error && <p className="mt-6 text-sm text-danger">Couldn&apos;t load prices. Please try again shortly.</p>}
      {!card && !error && <p className="mt-6 text-sm text-muted">Loading…</p>}
      {card?.categories.map((c) => (
        <section key={c.name} className="mt-8">
          <h2 className="border-b border-border pb-2 text-xs font-medium uppercase tracking-widest text-muted">{c.name}</h2>
          <ul className="divide-y divide-border text-sm">
            {c.items.map((i) => (
              <li key={i.name} className="flex justify-between py-2">
                <span>{i.name}</span>
                <span className="tnum">{inr(i.price)} <span className="text-muted">/ {UNIT[i.unit] ?? i.unit.toLowerCase()}</span></span>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}
