export const SUPPORT_EMAIL = 'support@washnlaundry.com';
export const SUPPORT_PHONE_DISPLAY = '08407 000 048';
export const SUPPORT_PHONE_TEL = '08407000048';

export default function SupportCard() {
  return (
    <div className="mt-8 rounded-xl border border-[#E4E0D8] bg-[#F8F7F5] p-4 text-left">
      <p className="text-xs font-bold text-[#141A24]">Still not working? Contact support</p>
      <p className="mt-2 text-xs text-[#64748B]">
        Email:{' '}
        <a href={`mailto:${SUPPORT_EMAIL}`} className="font-semibold text-[#182C4F] underline">
          {SUPPORT_EMAIL}
        </a>
      </p>
      <p className="mt-1 text-xs text-[#64748B]">
        Phone:{' '}
        <a href={`tel:${SUPPORT_PHONE_TEL}`} className="font-semibold text-[#182C4F] underline">
          {SUPPORT_PHONE_DISPLAY}
        </a>
      </p>
    </div>
  );
}
