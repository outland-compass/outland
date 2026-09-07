import { NextRequest, NextResponse } from 'next/server';

import { SESSION_COOKIE, verifySession } from '@/lib/session';

export function proxy(request: NextRequest) {
  try {
    if (verifySession(request.cookies.get(SESSION_COOKIE)?.value)) {
      const response = NextResponse.next();
      response.headers.set('Cache-Control', 'private, no-store');
      response.headers.set('X-Robots-Tag', 'noindex, nofollow, noarchive');
      return response;
    }
  } catch {
    // Treat invalid or missing server configuration as unauthenticated.
  }

  if (request.nextUrl.pathname.startsWith('/media/')) {
    return new NextResponse('Not found', { status: 404 });
  }

  const url = request.nextUrl.clone();
  url.pathname = '/';
  url.search = '';
  return NextResponse.redirect(url);
}

export const config = {
  matcher: ['/explore/:path*', '/media/:path*']
};
