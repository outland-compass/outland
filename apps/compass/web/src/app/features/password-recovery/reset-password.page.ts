import { Component, computed, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';

import { AuthService } from '../../core/auth/auth.service';

export const MIN_PASSWORD_LENGTH = 8;

/** Client-side checks before the password is sent to Supabase Auth; null when valid. */
export function newPasswordProblem(password: string, confirmation: string): string | null {
  if (password.length < MIN_PASSWORD_LENGTH) {
    return `Use at least ${MIN_PASSWORD_LENGTH} characters.`;
  }
  if (password !== confirmation) {
    return 'The passwords do not match.';
  }
  return null;
}

@Component({
  imports: [FormsModule, RouterLink],
  template: `
    <main class="page">
      <h1>Set a new password</h1>
      @if (canReset()) {
        <form (ngSubmit)="submit()">
          <label>New password
            <input name="password" type="password" autocomplete="new-password" [(ngModel)]="password" required>
          </label>
          <label>Repeat new password
            <input name="confirmation" type="password" autocomplete="new-password" [(ngModel)]="confirmation" required>
          </label>
          <button class="primary" type="submit" [disabled]="saving()">Save new password</button>
          <button class="quiet" type="button" [disabled]="saving()" (click)="cancel()">Cancel and sign out</button>
        </form>
        @if (error()) {
          <p class="state error" role="alert">{{ error() }}</p>
        }
      } @else {
        <p class="state error" role="alert">
          @if (auth.recoveryLinkError() === 'expired') {
            This password reset link has expired or was already used.
          } @else {
            Open the password reset link from your email to set a new password.
          }
        </p>
        <p><a routerLink="/forgot-password">Request a new reset link</a> · <a routerLink="/sign-in">Back to sign in</a></p>
      }
    </main>
  `
})
export default class ResetPasswordPage {
  password = '';
  confirmation = '';
  readonly saving = signal(false);
  readonly error = signal('');
  private readonly ended = signal(false);
  readonly canReset = computed(() => this.auth.recoveryMode() && !this.ended());

  constructor(readonly auth: AuthService, private readonly router: Router) {}

  async submit(): Promise<void> {
    const problem = newPasswordProblem(this.password, this.confirmation);
    if (problem) {
      this.error.set(problem);
      return;
    }

    this.saving.set(true);
    this.error.set('');
    const result = await this.auth.updatePassword(this.password);
    this.saving.set(false);

    if (!result.ok) {
      this.ended.set(result.recoveryEnded);
      this.error.set(result.message);
      return;
    }
    this.password = '';
    this.confirmation = '';
    await this.router.navigate(['/sign-in'], { queryParams: { reset: 'done' }, replaceUrl: true });
  }

  /** Leaves recovery without changing the password; the recovery session is revoked. */
  async cancel(): Promise<void> {
    this.saving.set(true);
    try {
      await this.auth.signOut();
    } finally {
      this.saving.set(false);
      this.password = '';
      this.confirmation = '';
    }
    await this.router.navigate(['/sign-in'], { replaceUrl: true });
  }
}
