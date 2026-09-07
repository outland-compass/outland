import { redirect } from 'next/navigation';
import { cookies } from 'next/headers';

import { AccessGate } from './access-gate';
import { SESSION_COOKIE, verifySession } from '@/lib/session';

export const dynamic = 'force-dynamic';

export default async function AccessPage() {
  const cookieStore = await cookies();

  try {
    if (verifySession(cookieStore.get(SESSION_COOKIE)?.value)) redirect('/explore');
  } catch {
    // A missing server configuration is presented by the form as unavailable.
  }

  return <AccessGate />;
}
