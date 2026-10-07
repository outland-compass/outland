import { NextRequest, NextResponse } from 'next/server';

import { STUDIO_SESSION_COOKIE, verifyStudioSession } from '@/lib/session';

export function proxy(request: NextRequest) {
  try {
    if (verifyStudioSession(request.cookies.get(STUDIO_SESSION_COOKIE)?.value)) {
      const response = NextResponse.next();
      response.headers.set('Cache-Control', 'private, no-store');
      response.headers.set('X-Robots-Tag', 'noindex, nofollow, noarchive');
      return response;
    }
  } catch {
    // Missing or invalid server configuration is treated as unauthenticated.
  }

  if (request.nextUrl.pathname.startsWith('/api/studio/')) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const url = request.nextUrl.clone();
  url.pathname = '/';
  url.search = '';
  return NextResponse.redirect(url);
}

export const config = {
  matcher: ['/studio/:path*', '/api/studio/:path*']
};
