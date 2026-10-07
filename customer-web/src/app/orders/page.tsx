'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useAuth } from '@/lib/auth';
import { api, ApiError, inr, Me, Order, STATUS_LABEL } from '@/lib/api';
import { SignInGate } from '@/components/SignInGate';

const shortDate = (iso: string) => new Date(iso).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });

function SignupForm({ token, defaultName, onDone }: { token: string; defaultName: string; onDone: (m: Me) => void }) {
  const [name, setName] = useState(defaultName);
  const [phone, setPhone] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      onDone(await api<Me>('customer/me/', { token, method: 'POST', body: { name, phone } }));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not create your account.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="max-w-sm space-y-4">
      <h1 className="font-serif text-2xl font-semibold text-primary">Finish signing up</h1>
      <p className="text-sm text-muted">We don&apos;t have an account for this email yet. Add your phone so the store can reach you about pickups.</p>
      <label className="block text-sm">Name
        <input className="field mt-1" value={name} onChange={(e) => setName(e.target.value)} required />
      </label>
      <label className="block text-sm">Phone
        <input className="field mt-1" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="10-digit mobile number" required />
      </label>
      {error && <p className="text-sm text-danger">{error}</p>}
      <button className="btn" disabled={busy}>{busy ? 'Creating…' : 'Create account'}</button>
    </form>
  );
}

export default function OrdersPage() {
  const { token, profile, ready } = useAuth();
  const [me, setMe] = useState<Me | null>(null);
  const [orders, setOrders] = useState<Order[] | null>(null);
  const [needsSignup, setNeedsSignup] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!token) return;
    let live = true;
    (async () => {
      try {
        const m = await api<Me>('customer/me/', { token });
        const o = await api<{ orders: Order[] }>('customer/orders/', { token });
        if (live) { setMe(m); setOrders(o.orders); setNeedsSignup(false); }
      } catch (err) {
        if (!live) return;
        if (err instanceof ApiError && err.status === 404) setNeedsSignup(true);
        else setError(err instanceof ApiError && err.status === 401 ? 'Your session expired. Sign out and sign in again.' : 'Could not load your orders.');
      }
    })();
    return () => { live = false; };
  }, [token]);

  if (!ready) return null;
  if (!token) return <SignInGate why="Orders are tied to your Google account, so we need you to sign in first." />;
  if (needsSignup) {
    return <SignupForm token={token} defaultName={profile?.name ?? ''} onDone={(m) => { setMe(m); setOrders([]); setNeedsSignup(false); }} />;
  }
  if (error) return <p className="text-sm text-danger">{error}</p>;
  if (!me || !orders) return <p className="text-sm text-muted">Loading…</p>;

  return (
    <div>
      <div className="flex flex-wrap items-end justify-between gap-4 border-b border-border pb-5">
        <div>
          <p className="text-sm text-muted">Hello, {me.name.split(' ')[0]}</p>
          <h1 className="font-serif text-2xl font-semibold text-primary">Your orders</h1>
        </div>
        <div className="text-right">
          <p className="text-xs uppercase tracking-widest text-muted">Outstanding</p>
          <p className={`tnum text-2xl font-semibold ${me.due_amount > 0 ? 'text-foreground' : 'text-ok'}`}>{inr(me.due_amount)}</p>
        </div>
      </div>

      {orders.length === 0 ? (
        <p className="mt-8 text-sm text-muted">
          No orders yet. <Link href="/book" className="text-accent hover:underline">Book a pickup</Link> and your first order will show up here.
        </p>
      ) : (
        <ul className="divide-y divide-border">
          {orders.map((o) => (
            <li key={o.order_number}>
              <Link href={`/orders/${encodeURIComponent(o.order_number)}`} className="flex items-center justify-between gap-4 py-4 hover:bg-secondary/60">
                <div>
                  <p className="tnum font-medium">{o.order_number}</p>
                  <p className="text-xs text-muted">{shortDate(o.created_at)} · {o.items.reduce((n, i) => n + i.quantity, 0)} items</p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-medium">{STATUS_LABEL[o.status] ?? o.status}</p>
                  <p className="tnum text-xs text-muted">
                    {inr(o.total_amount)}{o.due_amount > 0 ? ` · ${inr(o.due_amount)} due` : ' · paid'}
                  </p>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
