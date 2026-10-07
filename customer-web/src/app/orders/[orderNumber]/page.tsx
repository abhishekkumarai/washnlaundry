'use client';

import { use, useEffect, useState } from 'react';
import Link from 'next/link';
import { useAuth } from '@/lib/auth';
import { api, ApiError, inr, Order, STATUS_LABEL } from '@/lib/api';
import { SignInGate } from '@/components/SignInGate';
import { StatusTimeline } from '@/components/StatusTimeline';

export default function OrderPage({ params }: { params: Promise<{ orderNumber: string }> }) {
  const { orderNumber } = use(params);
  const { token, ready } = useAuth();
  const [order, setOrder] = useState<Order | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!token) return;
    let live = true;
    api<Order>(`customer/orders/${encodeURIComponent(orderNumber)}/`, { token })
      .then((o) => live && setOrder(o))
      .catch((err) => live && setError(err instanceof ApiError && err.status === 404 ? 'We couldn’t find that order on your account.' : 'Could not load this order.'));
    return () => { live = false; };
  }, [token, orderNumber]);

  if (!ready) return null;
  if (!token) return <SignInGate why="Sign in to see this order." />;
  if (error) return <p className="text-sm text-danger">{error}</p>;
  if (!order) return <p className="text-sm text-muted">Loading…</p>;

  const lines: [string, number][] = [['Subtotal', order.subtotal]];
  if (order.delivery_charge) lines.push(['Delivery', order.delivery_charge]);
  if (order.discount_amount) lines.push(['Discount', -order.discount_amount]);

  return (
    <div>
      <Link href="/orders" className="text-sm text-muted hover:text-foreground">← All orders</Link>
      <div className="mt-3 flex flex-wrap items-baseline justify-between gap-2 border-b border-border pb-5">
        <h1 className="tnum font-serif text-2xl font-semibold text-primary">{order.order_number}</h1>
        <p className="text-sm font-medium">{STATUS_LABEL[order.status] ?? order.status}{order.express ? ' · Express' : ''}</p>
      </div>

      <div className="mt-6 grid gap-10 sm:grid-cols-2">
        <section>
          <h2 className="mb-3 text-xs font-medium uppercase tracking-widest text-muted">Progress</h2>
          <StatusTimeline order={order} />
        </section>

        <section>
          <h2 className="mb-3 text-xs font-medium uppercase tracking-widest text-muted">Items</h2>
          <ul className="divide-y divide-border text-sm">
            {order.items.map((i, idx) => (
              <li key={idx} className="flex justify-between gap-3 py-2">
                <span>{i.quantity} × {i.title} <span className="text-muted">({i.service_type})</span></span>
                <span className="tnum">{inr(i.total_price)}</span>
              </li>
            ))}
          </ul>

          <dl className="tnum mt-4 space-y-1 border-t border-border pt-3 text-sm">
            {lines.map(([k, v]) => (
              <div key={k} className="flex justify-between"><dt className="text-muted">{k}</dt><dd>{inr(v)}</dd></div>
            ))}
            <div className="flex justify-between font-medium"><dt>Total</dt><dd>{inr(order.total_amount)}</dd></div>
            <div className="flex justify-between"><dt className="text-muted">Paid</dt><dd>{inr(order.paid_amount)}</dd></div>
            <div className={`flex justify-between font-medium ${order.due_amount > 0 ? '' : 'text-ok'}`}>
              <dt>{order.due_amount > 0 ? 'Due' : 'Settled'}</dt><dd>{inr(order.due_amount)}</dd>
            </div>
          </dl>
        </section>
      </div>
    </div>
  );
}
