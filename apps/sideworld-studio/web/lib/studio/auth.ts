import 'server-only';
import { NextRequest, NextResponse } from 'next/server';

const ACCESS = 'sw_studio_access';
const REFRESH = 'sw_studio_refresh';

function config() {
  const url = process.env.SUPABASE_URL?.trim();
  const key = process.env.SUPABASE_PUBLISHABLE_KEY?.trim();
  if (!url || !key) throw new Error('Studio Auth is not configured');
  return { url: url.replace(/\/$/, ''), key };
}

function headers(key: string, token?: string) {
  return { apikey: key, Authorization: `Bearer ${token ?? key}`, 'Content-Type': 'application/json' };
}

async function json(response: Response) {
  return response.json().catch(() => null) as Promise<Record<string, unknown> | null>;
}

export async function signIn(email: string, password: string) {
  const { url, key } = config();
  const response = await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: 'POST', headers: headers(key), body: JSON.stringify({ email, password }), cache: 'no-store'
  });
  if (!response.ok) return null;
  const body = await json(response);
  if (typeof body?.access_token !== 'string' || typeof body.refresh_token !== 'string') return null;
  return { access: body.access_token, refresh: body.refresh_token, expires: Number(body.expires_in) || 3600 };
}

async function refreshSession(refresh: string) {
  const { url, key } = config();
  const response = await fetch(`${url}/auth/v1/token?grant_type=refresh_token`, {
    method: 'POST', headers: headers(key), body: JSON.stringify({ refresh_token: refresh }), cache: 'no-store'
  });
  if (!response.ok) return null;
  const body = await json(response);
  if (typeof body?.access_token !== 'string' || typeof body.refresh_token !== 'string') return null;
  return { access: body.access_token, refresh: body.refresh_token, expires: Number(body.expires_in) || 3600 };
}

async function userAndRole(access: string) {
  const { url, key } = config();
  const userResponse = await fetch(`${url}/auth/v1/user`, {
    headers: headers(key, access), cache: 'no-store'
  });
  if (!userResponse.ok) return false;
  const user = await json(userResponse);
  if (typeof user?.id !== 'string') return false;
  // Existing can_admin() checks auth.uid() against shared.user_roles (OWNER/ADMIN).
  const roleResponse = await fetch(`${url}/rest/v1/rpc/can_admin`, {
    method: 'POST', headers: headers(key, access), body: '{}', cache: 'no-store'
  });
  if (!roleResponse.ok) return false;
  return (await roleResponse.json().catch(() => false)) === true;
}

export function setSession(response: NextResponse, session: { access: string; refresh: string; expires: number }) {
  const base = { httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'lax' as const, path: '/' };
  response.cookies.set(ACCESS, session.access, { ...base, maxAge: Math.min(session.expires, 3600) });
  response.cookies.set(REFRESH, session.refresh, { ...base, maxAge: 60 * 60 * 24 * 7 });
  response.headers.set('Cache-Control', 'private, no-store');
}

export function clearSession(response: NextResponse) {
  response.cookies.delete(ACCESS);
  response.cookies.delete(REFRESH);
  response.headers.set('Cache-Control', 'private, no-store');
}

export async function authorize(request: NextRequest, response: NextResponse) {
  try {
    let access = request.cookies.get(ACCESS)?.value;
    const refresh = request.cookies.get(REFRESH)?.value;
    if (access && await userAndRole(access)) return true;
    if (!refresh) return false;
    const renewed = await refreshSession(refresh);
    if (!renewed) return false;
    access = renewed.access;
    if (!await userAndRole(access)) return false;
    setSession(response, renewed);
    request.cookies.set(ACCESS, renewed.access);
    request.cookies.set(REFRESH, renewed.refresh);
    return true;
  } catch {
    return false;
  }
}

export async function checkCredentials(email: string, password: string) {
  const session = await signIn(email, password);
  if (!session) return null;
  if (!await userAndRole(session.access)) return null;
  return session;
}

export async function sendPasswordReset(email: string, redirectTo: string) {
  const { url, key } = config();
  await fetch(`${url}/auth/v1/recover?redirect_to=${encodeURIComponent(redirectTo)}`, {
    method: 'POST', headers: headers(key), body: JSON.stringify({ email }), cache: 'no-store'
  });
}
