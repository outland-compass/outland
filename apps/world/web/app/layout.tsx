import type { Metadata } from 'next';

import './globals.css';

export const metadata: Metadata = {
  title: 'OUTLAND — Access Restricted',
  description: 'A private OUTLAND visitor experience.',
  robots: {
    index: false,
    follow: false,
    nocache: true,
    googleBot: { index: false, follow: false, noimageindex: true }
  },
  openGraph: {
    title: 'OUTLAND',
    description: 'Access restricted.',
    type: 'website'
  }
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
