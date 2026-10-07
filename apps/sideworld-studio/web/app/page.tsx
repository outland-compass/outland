import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

import { StudioAccessGate } from './access-gate';
import { STUDIO_SESSION_COOKIE, verifyStudioSession } from '@/lib/session';

export const dynamic = 'force-dynamic';

export default async function AccessPage() {
  const cookieStore = await cookies();
  let authenticated = false;

  try {
    authenticated = verifyStudioSession(cookieStore.get(STUDIO_SESSION_COOKIE)?.value);
  } catch {
    authenticated = false;
  }

  if (authenticated) {
    redirect('/studio');
  }

  return <StudioAccessGate />;
}
