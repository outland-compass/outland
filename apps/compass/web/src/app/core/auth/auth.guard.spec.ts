import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter, Router, UrlTree } from '@angular/router';
import type { Session } from '@supabase/supabase-js';
import { describe, expect, it } from 'vitest';

import { authGuard } from './auth.guard';
import { AuthService } from './auth.service';

function runGuard(state: { session: Session | null; recoveryMode: boolean }): string | true {
  TestBed.configureTestingModule({
    providers: [
      provideRouter([]),
      { provide: AuthService, useValue: { session: signal(state.session), recoveryMode: signal(state.recoveryMode) } }
    ]
  });
  const result = TestBed.runInInjectionContext(() => authGuard({} as never, {} as never));
  return result instanceof UrlTree ? TestBed.inject(Router).serializeUrl(result) : (result as true);
}

describe('authGuard', () => {
  const session = { access_token: 'token' } as Session;

  it('lets a signed-in session into COMPASS', () => {
    expect(runGuard({ session, recoveryMode: false })).toBe(true);
  });

  it('sends visitors without a session to sign-in', () => {
    expect(runGuard({ session: null, recoveryMode: false })).toBe('/sign-in');
  });

  it('keeps a recovery session on the reset-password page', () => {
    expect(runGuard({ session, recoveryMode: true })).toBe('/reset-password');
  });
});
