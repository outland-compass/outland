import type { Session } from '@supabase/supabase-js';
import { describe, expect, it, vi } from 'vitest';

import { SupabaseService } from '../supabase/supabase.service';
import { AuthService } from './auth.service';

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

function authService(options: {
  restored: Session | null;
  refreshed?: Session | null;
  refreshError?: { message: string } | null;
}) {
  const getSession = vi.fn().mockResolvedValue({ data: { session: options.restored }, error: null });
  const refreshSession = vi.fn().mockResolvedValue({
    data: { session: options.refreshed ?? null },
    error: options.refreshError ?? null
  });
  const onAuthStateChange = vi.fn();

  const supabase = {
    isConfigured: true,
    client: {
      auth: { getSession, refreshSession, onAuthStateChange }
    }
  } as unknown as SupabaseService;

  return {
    service: new AuthService(supabase),
    getSession,
    refreshSession,
    onAuthStateChange
  };
}

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
