import { computed, Injectable, signal } from '@angular/core';
import { AuthError, Session } from '@supabase/supabase-js';

import { SupabaseService } from '../supabase/supabase.service';

export const RESET_PASSWORD_PATH = '/reset-password';

/** Why a recovery link could not be used: `expired` covers expired and already used links. */
export type RecoveryLinkError = 'expired' | 'invalid';

export type PasswordResetRequestResult = 'sent' | 'failed';

export type PasswordUpdateResult =
  | { ok: true }
  | { ok: false; message: string; recoveryEnded: boolean };

type RecoveryRedirect =
  | { accessToken: string; refreshToken: string }
  | { error: RecoveryLinkError };

const AUTH_REDIRECT_PARAMS = ['code', 'error', 'error_code', 'error_description'];
const ENDED_RECOVERY_CODES = new Set(['session_not_found', 'session_expired', 'bad_jwt', 'refresh_token_not_found']);

/** True when the access token was issued by a recovery link (`amr` method `recovery`). */
export function isRecoverySession(session: Session | null): boolean {
  const payload = session?.access_token.split('.')[1];
  if (!payload) {
    return false;
  }

  try {
    const claims = JSON.parse(atob(payload.replace(/-/g, '+').replace(/_/g, '/'))) as {
      amr?: { method?: string }[];
    };
    return Array.isArray(claims.amr) && claims.amr.some((entry) => entry?.method === 'recovery');
  } catch {
    return false;
  }
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  readonly session = signal<Session | null>(null);
  readonly ready = signal(false);
  readonly error = signal<string | null>(null);
  readonly recoveryLinkError = signal<RecoveryLinkError | null>(null);

  private readonly recoveryStarted = signal(false);
  /** A valid recovery session exists: only setting a new password is allowed. */
  readonly recoveryMode = computed(() => {
    const session = this.session();
    return Boolean(session) && (this.recoveryStarted() || isRecoverySession(session));
  });

  constructor(private readonly supabase: SupabaseService) {}

  async restoreSession(): Promise<void> {
    if (!this.supabase.isConfigured) {
      this.ready.set(true);
      return;
    }

    try {
      const recovery = this.consumeRecoveryRedirect();

      if (recovery && 'error' in recovery) {
        this.recoveryLinkError.set(recovery.error);
      }

      if (recovery && 'accessToken' in recovery) {
        const { data, error } = await this.supabase.client.auth.setSession({
          access_token: recovery.accessToken,
          refresh_token: recovery.refreshToken
        });
        if (error || !data.session) {
          this.recoveryLinkError.set('expired');
        } else {
          this.recoveryStarted.set(true);
        }
        this.session.set(data.session ?? null);
      } else {
        const { data, error } = await this.supabase.client.auth.getSession();
        if (error) {
          this.error.set(error.message);
          return;
        }

        let restoredSession = data.session;

        if (restoredSession) {
          const { data: refreshed, error: refreshError } = await this.supabase.client.auth.refreshSession();
          if (!refreshError && refreshed.session) {
            restoredSession = refreshed.session;
          }
        }

        this.session.set(restoredSession);
      }

      this.supabase.client.auth.onAuthStateChange((_event, nextSession) => {
        this.session.set(nextSession);
      });
    } catch {
      this.error.set('Authentication could not be initialized. Please verify local configuration.');
    } finally {
      this.ready.set(true);
    }
  }

  async signIn(email: string, password: string): Promise<string | null> {
    const { error } = await this.supabase.client.auth.signInWithPassword({ email, password });
    if (!error) {
      this.recoveryStarted.set(false);
    }
    return error?.message ?? null;
  }

  async signOut(): Promise<void> {
    this.recoveryStarted.set(false);
    if (this.supabase.isConfigured) {
      await this.supabase.client.auth.signOut();
    }
  }

  /**
   * Asks Supabase Auth to email a recovery link that returns to /reset-password on this origin.
   * Rate limiting (429) is reported as `sent`: Supabase only rate-limits existing accounts, so a
   * distinct message would reveal whether the address has an account.
   */
  async requestPasswordReset(email: string): Promise<PasswordResetRequestResult> {
    try {
      const { error } = await this.supabase.client.auth.resetPasswordForEmail(email.trim(), {
        redirectTo: `${window.location.origin}${RESET_PASSWORD_PATH}`
      });
      return !error || error.status === 429 ? 'sent' : 'failed';
    } catch {
      return 'failed';
    }
  }

  /** Sets the new password for the recovery session, then revokes the session. */
  async updatePassword(password: string): Promise<PasswordUpdateResult> {
    if (!this.recoveryMode()) {
      return { ok: false, message: 'This recovery link is no longer valid.', recoveryEnded: true };
    }

    let error: AuthError | null;
    try {
      ({ error } = await this.supabase.client.auth.updateUser({ password }));
    } catch {
      return { ok: false, message: 'The password could not be updated. Please try again.', recoveryEnded: false };
    }

    if (error) {
      const recoveryEnded = error.status === 401 || ENDED_RECOVERY_CODES.has(error.code ?? '');
      if (recoveryEnded) {
        this.recoveryLinkError.set('expired');
      }
      return { ok: false, message: error.message, recoveryEnded };
    }

    try {
      await this.signOut();
    } catch {
      // The password is already changed; supabase-js clears the local session even if revocation fails.
    }
    return { ok: true };
  }

  /**
   * Reads a Supabase recovery redirect (implicit flow: tokens in the fragment; errors in the fragment
   * or query) and removes it from the address bar by replacing the current history entry.
   */
  private consumeRecoveryRedirect(): RecoveryRedirect | null {
    if (typeof window === 'undefined') {
      return null;
    }

    const url = new URL(window.location.href);
    const fragment = new URLSearchParams(url.hash.replace(/^#/, ''));
    const hasTokens = fragment.has('access_token') || fragment.has('refresh_token');
    const isRecovery = fragment.get('type') === 'recovery';
    const errorParams = url.pathname === RESET_PASSWORD_PATH
      ? [fragment, url.searchParams].find((params) => params.has('error') || params.has('error_code'))
      : undefined;

    if (!hasTokens && !errorParams && !(url.pathname === RESET_PASSWORD_PATH && url.searchParams.has('code'))) {
      return null;
    }

    const accessToken = fragment.get('access_token');
    const refreshToken = fragment.get('refresh_token');
    const errorCode = errorParams?.get('error_code');

    url.hash = '';
    for (const param of AUTH_REDIRECT_PARAMS) {
      url.searchParams.delete(param);
    }
    if (hasTokens && isRecovery) {
      url.pathname = RESET_PASSWORD_PATH;
    }
    window.history.replaceState(window.history.state, '', `${url.pathname}${url.search}`);

    if (errorParams) {
      return { error: errorCode === 'otp_expired' ? 'expired' : 'invalid' };
    }
    if (!hasTokens || !isRecovery) {
      // A PKCE code or non-recovery tokens: this app does not use them; they are only removed.
      return url.pathname === RESET_PASSWORD_PATH ? { error: 'invalid' } : null;
    }
    if (!accessToken || !refreshToken) {
      return { error: 'invalid' };
    }
    return { accessToken, refreshToken };
  }
}
