import { Component, OnDestroy, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { AuthService } from '../../core/auth/auth.service';

export const RESEND_COOLDOWN_SECONDS = 60;

@Component({
  imports: [FormsModule, RouterLink],
  template: `
    <main class="page">
      <h1>Forgot password</h1>
      @if (sent()) {
        <p class="state" role="status">
          If an account exists for this email address, a password reset link is on its way.
          Open the link in this browser. It can take a few minutes to arrive.
        </p>
        <button class="quiet" type="button" [disabled]="sending() || cooldown() > 0" (click)="submit()">
          {{ cooldown() > 0 ? 'Send again in ' + cooldown() + 's' : 'Send again' }}
        </button>
      } @else {
        <p class="muted">Enter the email address of your COMPASS account.</p>
        <form (ngSubmit)="submit()">
          <input name="email" type="email" autocomplete="email" [(ngModel)]="email" required>
          <button class="primary" type="submit" [disabled]="sending() || !email.trim()">Send reset link</button>
        </form>
      }
      @if (error()) {
        <p class="state error" role="alert">{{ error() }}</p>
      }
      <p><a routerLink="/sign-in">Back to sign in</a></p>
    </main>
  `
})
export default class ForgotPasswordPage implements OnDestroy {
  email = '';
  readonly sending = signal(false);
  readonly sent = signal(false);
  readonly cooldown = signal(0);
  readonly error = signal('');
  private timer?: ReturnType<typeof setInterval>;

  constructor(private readonly auth: AuthService) {}

  async submit(): Promise<void> {
    if (this.sending() || this.cooldown() > 0 || !this.email.trim()) {
      return;
    }

    this.sending.set(true);
    this.error.set('');
    const result = await this.auth.requestPasswordReset(this.email);
    this.sending.set(false);

    if (result === 'failed') {
      this.error.set('The request could not be sent. Check the email address and try again.');
      return;
    }
    this.sent.set(true);
    this.startCooldown();
  }

  ngOnDestroy(): void {
    clearInterval(this.timer);
  }

  private startCooldown(): void {
    clearInterval(this.timer);
    this.cooldown.set(RESEND_COOLDOWN_SECONDS);
    this.timer = setInterval(() => {
      this.cooldown.update((seconds) => Math.max(seconds - 1, 0));
      if (this.cooldown() === 0) {
        clearInterval(this.timer);
      }
    }, 1000);
  }
}
