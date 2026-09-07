import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

import { SESSION_COOKIE, verifySession } from '@/lib/session';
import { Experience } from './experience';

export default async function ExplorePage() {
  const session = (await cookies()).get(SESSION_COOKIE)?.value;
  if (!session || !verifySession(session)) redirect('/');

  return <Experience />;
}
