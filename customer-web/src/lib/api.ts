export class ApiError extends Error {
  constructor(public status: number, message: string, public data?: Record<string, unknown>) {
    super(message);
  }
}

/** Calls the same-origin BFF (/api/portal/*), which forwards to the Django backend. */
export async function api<T>(
  path: string,
  opts: { token?: string | null; method?: 'GET' | 'POST'; body?: unknown } = {},
): Promise<T> {
  const res = await fetch(`/api/portal/${path}`, {
    method: opts.method ?? 'GET',
    headers: {
      ...(opts.token ? { Authorization: `Bearer ${opts.token}` } : {}),
      ...(opts.body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new ApiError(res.status, data.detail ?? 'Something went wrong.', data);
  return data as T;
}

export type OrderItem = {
  title: string; service_type: string; quantity: number; unit: string;
  unit_price: number; total_price: number;
};

export type Order = {
  order_number: string; status: string; payment_status: string; delivery_type: string;
  express: boolean; subtotal: number; delivery_charge: number; discount_amount: number;
  total_amount: number; paid_amount: number; due_amount: number;
  scheduled_date: string | null; scheduled_time: string | null;
  pickup_date: string | null; pickup_time: string | null; created_at: string;
  placed_at: string | null; processing_at: string | null; ironing_at: string | null;
  ready_at: string | null; out_for_delivery_at: string | null; delivered_at: string | null;
  cancelled_at: string | null; items: OrderItem[];
};

export type Me = { name: string; email: string; total_orders: number; due_amount: number };
export type RateCard = { categories: { name: string; items: { name: string; price: number; unit: string }[] }[] };

export const inr = (n: number) =>
  new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(n);

export const STATUS_LABEL: Record<string, string> = {
  PLACED: 'Placed', PROCESSING: 'Processing', IRONING: 'Ironing', READY: 'Ready',
  OUT_FOR_DELIVERY: 'Out for delivery', DELIVERED: 'Delivered', CANCELLED: 'Cancelled',
};
