import { Component, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { AuthService } from '../../core/auth/auth.service';

@Component({
  imports: [FormsModule, RouterLink],
  template: `<main><h1>Sign in</h1>@if (passwordReset) {<p role="status">Your password was updated. Sign in with the new password.</p>}<form (ngSubmit)="submit()"><input name="email" type="email" [(ngModel)]="email" required><input name="password" type="password" [(ngModel)]="password" required><button type="submit">Sign in</button></form><p><a routerLink="/forgot-password">Forgot password?</a></p><p>{{ error() || auth.error() }}</p></main>`
})
export default class SignInPage {
  email = '';
  password = '';
  readonly error = signal('');
  readonly passwordReset: boolean;

  constructor(readonly auth: AuthService, private readonly router: Router, route: ActivatedRoute) {
    this.passwordReset = route.snapshot.queryParamMap.get('reset') === 'done';
  }

  async submit(): Promise<void> {
    const error = await this.auth.signIn(this.email, this.password);
    if (error) {
      this.error.set(error);
      return;
    }
    await this.router.navigateByUrl('/radar');
  }
}
