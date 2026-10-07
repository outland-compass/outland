import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

import { StudioAccessGate } from './access-gate';
import { STUDIO_SESSION_COOKIE, verifyStudioSession } from '@/lib/session';

export const dynamic = 'force-dynamic';

export default async function AccessPage() {
  const cookieStore = await cookies();

  try {
    if (verifyStudioSession(cookieStore.get(STUDIO_SESSION_COOKIE)?.value)) {
      redirect('/studio');
    }
  } catch {
    // Missing server configuration is presented by the access form.
  }

  return <StudioAccessGate />;
}
