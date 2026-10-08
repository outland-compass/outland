import type { Session } from '@supabase/supabase-js';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { SupabaseService } from '../supabase/supabase.service';
import { AuthService, isRecoverySession } from './auth.service';

function session(accessToken: string): Session {
  return {
    access_token: accessToken,
    refresh_token: `refresh-${accessToken}`,
    expires_in: 3600,
    expires_at: 1_900_000_000,
    token_type: 'bearer',
    user: {} as Session['user']
  };
}

function base64Url(value: object): string {
  return btoa(JSON.stringify(value)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function jwt(amrMethods: string[]): string {
  return `${base64Url({ alg: 'HS256' })}.${base64Url({ sub: 'user-1', amr: amrMethods.map((method) => ({ method, timestamp: 1 })) })}.signature`;
}

type AuthErrorLike = { message: string; status?: number; code?: string } | null;

function authService(options: {
  restored: Session | null;
  refreshed?: Session | null;
  refreshError?: { message: string } | null;
  recoverySession?: Session | null;
  setSessionError?: AuthErrorLike;
  resetError?: AuthErrorLike;
  updateError?: AuthErrorLike;
}) {
  const getSession = vi.fn().mockResolvedValue({ data: { session: options.restored }, error: null });
  const refreshSession = vi.fn().mockResolvedValue({
    data: { session: options.refreshed ?? null },
    error: options.refreshError ?? null
  });
  const onAuthStateChange = vi.fn();
  const setSession = vi.fn().mockResolvedValue({
    data: { session: options.recoverySession ?? null },
    error: options.setSessionError ?? null
  });
  const resetPasswordForEmail = vi.fn().mockResolvedValue({ data: {}, error: options.resetError ?? null });
  const updateUser = vi.fn().mockResolvedValue({ data: {}, error: options.updateError ?? null });
  const signOut = vi.fn().mockResolvedValue({ error: null });

  const supabase = {
    isConfigured: true,
    client: {
      auth: { getSession, refreshSession, onAuthStateChange, setSession, resetPasswordForEmail, updateUser, signOut }
    }
  } as unknown as SupabaseService;

  return {
    service: new AuthService(supabase),
    getSession,
    refreshSession,
    onAuthStateChange,
    setSession,
    resetPasswordForEmail,
    updateUser,
    signOut
  };
}

const RECOVERY_FRAGMENT =
  '#access_token=recovery-access&expires_at=1900000000&expires_in=3600&refresh_token=recovery-refresh&token_type=bearer&type=recovery';

describe('AuthService restoreSession', () => {
  it('refreshes an existing stored session before marking auth ready', async () => {
    const restored = session('stale');
    const refreshed = session('fresh');
    const { service, refreshSession, onAuthStateChange } = authService({ restored, refreshed });

    await service.restoreSession();

    expect(refreshSession).toHaveBeenCalledTimes(1);
    expect(service.session()).toBe(refreshed);
    expect(service.ready()).toBe(true);
    expect(service.error()).toBeNull();
    expect(onAuthStateChange).toHaveBeenCalledTimes(1);
  });

  it('does not refresh when there is no stored session', async () => {
    const { service, refreshSession } = authService({ restored: null });

    await service.restoreSession();

    expect(refreshSession).not.toHaveBeenCalled();
    expect(service.session()).toBeNull();
    expect(service.ready()).toBe(true);
  });

  it('keeps the restored session when refresh fails', async () => {
    const restored = session('existing');
    const { service } = authService({
      restored,
      refreshError: { message: 'temporary refresh failure' }
    });

    await service.restoreSession();

    expect(service.session()).toBe(restored);
    expect(service.ready()).toBe(true);
  });
});

describe('AuthService password recovery redirect', () => {
  afterEach(() => window.history.replaceState(null, '', '/'));

  it('starts a recovery session from the link and removes the tokens from the address bar', async () => {
    window.history.replaceState(null, '', `/reset-password${RECOVERY_FRAGMENT}`);
    const recovery = session(jwt(['recovery']));
    const { service, setSession, getSession } = authService({ restored: null, recoverySession: recovery });

    await service.restoreSession();

    expect(setSession).toHaveBeenCalledWith({ access_token: 'recovery-access', refresh_token: 'recovery-refresh' });
    expect(getSession).not.toHaveBeenCalled();
    expect(window.location.pathname).toBe('/reset-password');
    expect(window.location.hash).toBe('');
    expect(window.location.href).not.toContain('recovery-access');
    expect(service.session()).toBe(recovery);
    expect(service.recoveryMode()).toBe(true);
    expect(service.recoveryLinkError()).toBeNull();
  });

  it('moves a recovery redirect that landed on another path to /reset-password', async () => {
    window.history.replaceState(null, '', `/${RECOVERY_FRAGMENT}`);
    const { service } = authService({ restored: null, recoverySession: session(jwt(['recovery'])) });

    await service.restoreSession();

    expect(window.location.pathname).toBe('/reset-password');
    expect(window.location.hash).toBe('');
    expect(service.recoveryMode()).toBe(true);
  });

  it('reports an expired or used link without creating a session', async () => {
    window.history.replaceState(
      null,
      '',
      '/reset-password#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired'
    );
    const { service, setSession } = authService({ restored: null });

    await service.restoreSession();

    expect(setSession).not.toHaveBeenCalled();
    expect(window.location.hash).toBe('');
    expect(service.recoveryLinkError()).toBe('expired');
    expect(service.recoveryMode()).toBe(false);
  });

  it('reports a link whose session Supabase rejects as expired', async () => {
    window.history.replaceState(null, '', `/reset-password${RECOVERY_FRAGMENT}`);
    const { service } = authService({ restored: null, setSessionError: { message: 'Invalid Refresh Token', status: 400 } });

    await service.restoreSession();

    expect(window.location.hash).toBe('');
    expect(service.session()).toBeNull();
    expect(service.recoveryMode()).toBe(false);
    expect(service.recoveryLinkError()).toBe('expired');
  });

  it('keeps recovery mode after a reload through the recovery amr claim', async () => {
    window.history.replaceState(null, '', '/reset-password');
    const recovery = session(jwt(['recovery']));
    const { service } = authService({ restored: recovery, refreshed: recovery });

    await service.restoreSession();

    expect(service.recoveryMode()).toBe(true);
  });

  it('does not treat a password session as a recovery session', async () => {
    const { service } = authService({ restored: session(jwt(['password'])) });

    await service.restoreSession();

    expect(service.session()).not.toBeNull();
    expect(service.recoveryMode()).toBe(false);
  });
});

describe('AuthService password reset', () => {
  afterEach(() => window.history.replaceState(null, '', '/'));

  it('requests a recovery email that returns to /reset-password on this origin', async () => {
    const { service, resetPasswordForEmail } = authService({ restored: null });

    expect(await service.requestPasswordReset('  user@example.com ')).toBe('sent');
    expect(resetPasswordForEmail).toHaveBeenCalledWith('user@example.com', {
      redirectTo: `${window.location.origin}/reset-password`
    });
  });

  it('answers a rate-limited request like a sent one so account existence is not revealed', async () => {
    const { service } = authService({ restored: null, resetError: { message: 'rate limited', status: 429 } });

    expect(await service.requestPasswordReset('user@example.com')).toBe('sent');
  });

  it('reports other request failures', async () => {
    const { service } = authService({
      restored: null,
      resetError: { message: 'Unable to validate email address', status: 400 }
    });

    expect(await service.requestPasswordReset('not-an-email')).toBe('failed');
  });

  it('updates the password and then revokes the recovery session', async () => {
    window.history.replaceState(null, '', `/reset-password${RECOVERY_FRAGMENT}`);
    const { service, updateUser, signOut } = authService({ restored: null, recoverySession: session(jwt(['recovery'])) });
    await service.restoreSession();

    expect(await service.updatePassword('a-new-password')).toEqual({ ok: true });
    expect(updateUser).toHaveBeenCalledWith({ password: 'a-new-password' });
    expect(signOut).toHaveBeenCalledTimes(1);
    expect(updateUser.mock.invocationCallOrder[0]).toBeLessThan(signOut.mock.invocationCallOrder[0]);
  });

  it('refuses a password update without a recovery session', async () => {
    const { service, updateUser } = authService({ restored: session(jwt(['password'])) });
    await service.restoreSession();

    const result = await service.updatePassword('a-new-password');

    expect(result.ok).toBe(false);
    expect(updateUser).not.toHaveBeenCalled();
  });

  it('keeps the session and reports Supabase validation errors', async () => {
    window.history.replaceState(null, '', `/reset-password${RECOVERY_FRAGMENT}`);
    const { service, signOut } = authService({
      restored: null,
      recoverySession: session(jwt(['recovery'])),
      updateError: { message: 'New password should be different from the old password.', status: 422, code: 'same_password' }
    });
    await service.restoreSession();

    expect(await service.updatePassword('the-old-password')).toEqual({
      ok: false,
      message: 'New password should be different from the old password.',
      recoveryEnded: false
    });
    expect(signOut).not.toHaveBeenCalled();
    expect(service.recoveryMode()).toBe(true);
  });

  it('ends the recovery flow when Supabase rejects the session', async () => {
    window.history.replaceState(null, '', `/reset-password${RECOVERY_FRAGMENT}`);
    const { service } = authService({
      restored: null,
      recoverySession: session(jwt(['recovery'])),
      updateError: { message: 'Session not found', status: 403, code: 'session_not_found' }
    });
    await service.restoreSession();

    const result = await service.updatePassword('a-new-password');

    expect(result).toMatchObject({ ok: false, recoveryEnded: true });
    expect(service.recoveryLinkError()).toBe('expired');
  });
});

describe('isRecoverySession', () => {
  it('reads the amr claim and tolerates malformed tokens', () => {
    expect(isRecoverySession(session(jwt(['recovery'])))).toBe(true);
    expect(isRecoverySession(session(jwt(['password'])))).toBe(false);
    expect(isRecoverySession(session('not-a-jwt'))).toBe(false);
    expect(isRecoverySession(null)).toBe(false);
  });
});
