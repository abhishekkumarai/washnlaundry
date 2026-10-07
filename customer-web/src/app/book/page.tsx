'use client';

import { useState } from 'react';
import { api, ApiError } from '@/lib/api';

const SERVICES = ['Wash & fold', 'Wash & iron', 'Dry cleaning', 'Steam iron only', 'Not sure yet'];

export default function BookPage() {
  const [form, setForm] = useState({ name: '', phone: '', address: '', service: SERVICES[1], website: '' });
  const [state, setState] = useState<'idle' | 'busy' | 'done'>('idle');
  const [error, setError] = useState('');
  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }));

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setState('busy');
    setError('');
    try {
      await api('leads/public/', { method: 'POST', body: form });
      setState('done');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not send your request.');
      setState('idle');
    }
  }

  if (state === 'done') {
    return (
      <section className="max-w-md">
        <h1 className="font-serif text-2xl font-semibold text-primary">Request received</h1>
        <p className="mt-2 text-sm text-muted">We&apos;ll call you on {form.phone} to confirm the pickup slot.</p>
      </section>
    );
  }

  return (
    <form onSubmit={submit} className="max-w-md space-y-4">
      <h1 className="font-serif text-2xl font-semibold text-primary">Book a pickup</h1>
      <p className="text-sm text-muted">Tell us where to collect from. We&apos;ll call to confirm a slot.</p>
      <label className="block text-sm">Name
        <input className="field mt-1" value={form.name} onChange={set('name')} required />
      </label>
      <label className="block text-sm">Phone
        <input className="field mt-1" inputMode="tel" value={form.phone} onChange={set('phone')} required />
      </label>
      <label className="block text-sm">Pickup address
        <textarea className="field mt-1" rows={3} value={form.address} onChange={set('address')} required />
      </label>
      <label className="block text-sm">Service
        <select className="field mt-1" value={form.service} onChange={set('service')}>
          {SERVICES.map((s) => <option key={s}>{s}</option>)}
        </select>
      </label>
      {/* Honeypot: hidden from people, filled by bots. The backend drops submissions that set it. */}
      <input className="hidden" tabIndex={-1} autoComplete="off" aria-hidden value={form.website} onChange={set('website')} name="website" />
      {error && <p className="text-sm text-danger">{error}</p>}
      <button className="btn" disabled={state === 'busy'}>{state === 'busy' ? 'Sending…' : 'Request pickup'}</button>
    </form>
  );
}
