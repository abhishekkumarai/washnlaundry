import { Order, STATUS_LABEL } from '@/lib/api';

const STAGES: { status: string; field: keyof Order }[] = [
  { status: 'PLACED', field: 'placed_at' },
  { status: 'PROCESSING', field: 'processing_at' },
  { status: 'IRONING', field: 'ironing_at' },
  { status: 'READY', field: 'ready_at' },
  { status: 'OUT_FOR_DELIVERY', field: 'out_for_delivery_at' },
  { status: 'DELIVERED', field: 'delivered_at' },
];

const when = (iso: string | null) =>
  iso ? new Date(iso).toLocaleString('en-IN', { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }) : '';

export function StatusTimeline({ order }: { order: Order }) {
  if (order.status === 'CANCELLED') {
    return <p className="text-sm text-danger">Cancelled {when(order.cancelled_at)}</p>;
  }
  const current = STAGES.findIndex((s) => s.status === order.status);
  return (
    <ol className="border-l border-border">
      {STAGES.map((s, i) => {
        const at = order[s.field] as string | null;
        const done = i <= current;
        return (
          <li key={s.status} className="relative pb-5 pl-6 last:pb-0">
            <span
              className={`absolute -left-[5px] top-1.5 h-2.5 w-2.5 rounded-full ${
                i === current ? 'bg-accent ring-4 ring-accent/15' : done ? 'bg-primary' : 'bg-border'
              }`}
            />
            <div className={`text-sm ${done ? 'font-medium text-foreground' : 'text-muted'}`}>{STATUS_LABEL[s.status]}</div>
            {at && <div className="tnum text-xs text-muted">{when(at)}</div>}
          </li>
        );
      })}
    </ol>
  );
}
