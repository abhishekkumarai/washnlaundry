import type { Metadata } from 'next';
import './globals.css';
import { CartProvider } from '../context/CartContext';
import { Analytics } from '@vercel/analytics/react';
import { SpeedInsights } from '@vercel/speed-insights/next';
import Script from 'next/script';

export const metadata: Metadata = {
  title: 'WashNLaundry - Premium Eco-Care Garment Specialists',
  description: 'Doorstep pickup, zero-harsh-chemical organic wash, artisan steam press, and 24-hour delivery across Patna.',
  keywords: 'laundry, dry cleaning, wash and fold, wash and iron, steam iron, WashNLaundry, patna, bihar, sustainable laundry',
  metadataBase: new URL('https://washnlaundry.com'),
  alternates: {
    canonical: '/',
  },
  verification: {
    google: 'OXGqeEEG9kQYtJKJSEHabBEawVcCzyqqniDqwW6PvIA',
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const gaId = process.env.NEXT_PUBLIC_GA_ID;

  return (
    <html lang="en">
      <body className="min-h-screen">
        <CartProvider>
          {children}
        </CartProvider>
        <Analytics />
        <SpeedInsights />
        {gaId && (
          <>
            <Script
              src={`https://www.googletagmanager.com/gtag/js?id=${gaId}`}
              strategy="afterInteractive"
            />
            <Script id="google-analytics" strategy="afterInteractive">
              {`
                window.dataLayer = window.dataLayer || [];
                function gtag(){dataLayer.push(arguments);}
                gtag('js', new Date());
                gtag('config', '${gaId}');
              `}
            </Script>
          </>
        )}
      </body>
    </html>
  );
}
