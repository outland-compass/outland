import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { describe, expect, it, vi } from 'vitest';

import { AuthService } from '../../core/auth/auth.service';
import ResetPasswordPage, { newPasswordProblem } from './reset-password.page';

describe('newPasswordProblem', () => {
  it('requires at least 8 characters', () => {
    expect(newPasswordProblem('short', 'short')).toBe('Use at least 8 characters.');
  });

  it('requires a matching confirmation', () => {
    expect(newPasswordProblem('long-enough', 'long-enougH')).toBe('The passwords do not match.');
  });

  it('accepts a long, confirmed password', () => {
    expect(newPasswordProblem('long-enough', 'long-enough')).toBeNull();
  });
});

describe('ResetPasswordPage', () => {
  function render(recoveryMode: boolean) {
    const auth = {
      recoveryMode: signal(recoveryMode),
      recoveryLinkError: signal(null),
      signOut: vi.fn().mockResolvedValue(undefined),
      updatePassword: vi.fn()
    };
    TestBed.configureTestingModule({
      imports: [ResetPasswordPage],
      providers: [provideRouter([]), { provide: AuthService, useValue: auth }]
    });
    const navigate = vi.spyOn(TestBed.inject(Router), 'navigate').mockResolvedValue(true);
    const fixture = TestBed.createComponent(ResetPasswordPage);
    fixture.detectChanges();
    return { auth, navigate, fixture, element: fixture.nativeElement as HTMLElement };
  }

  it('lets a recovery session leave without changing the password', async () => {
    const { auth, navigate, element } = render(true);
    const cancel = Array.from(element.querySelectorAll('button')).find((button) =>
      button.textContent?.includes('Cancel and sign out')
    );

    cancel?.click();
    await vi.waitFor(() => expect(navigate).toHaveBeenCalledWith(['/sign-in'], { replaceUrl: true }));

    expect(auth.signOut).toHaveBeenCalledTimes(1);
    expect(auth.updatePassword).not.toHaveBeenCalled();
  });

  it('shows no password form without a recovery session', () => {
    const { element } = render(false);

    expect(element.querySelector('input[type=password]')).toBeNull();
    expect(element.textContent).toContain('Request a new reset link');
  });
});
