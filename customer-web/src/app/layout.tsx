import type { Metadata } from 'next';
import './globals.css';
import { AuthProvider } from '@/lib/auth';
import { Header } from '@/components/Header';

export const metadata: Metadata = {
  title: 'My orders | WashNLaundry',
  description: 'Track your WashNLaundry orders, see what you owe, and book a pickup.',
  metadataBase: new URL('https://customer.washnlaundry.com'),
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen">
        <AuthProvider>
          <Header />
          <main className="mx-auto w-full max-w-3xl px-4 pb-20 pt-8 sm:px-6">{children}</main>
        </AuthProvider>
      </body>
    </html>
  );
}
