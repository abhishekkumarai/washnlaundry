import type { Metadata } from 'next';
import './globals.css';
import { CartProvider } from '../context/CartContext';
import Navbar from '../components/Navbar/Navbar';
import Footer from '../components/Footer/Footer';
import { Analytics } from '@vercel/analytics/react';
import { SpeedInsights } from '@vercel/speed-insights/next';
import Script from 'next/script';

export const metadata: Metadata = {
  title: 'WashNLaundry - Professional Laundry & Dry Cleaning on Autopilot',
  description: 'Sustainable, clean, and fast laundry and dry cleaning services with doorstep pickup & delivery in 24 hours. Affordable neighborhood rates.',
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
      <body>
        <CartProvider>
          <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
            <Navbar />
            <main style={{ flex: 1 }}>{children}</main>
            <Footer />
          </div>
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



