import { Component, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';

import { AuthService } from '../../core/auth/auth.service';

@Component({
  imports: [FormsModule],
  template: `<main><h1>Sign in</h1><form (ngSubmit)="submit()"><input name="email" type="email" [(ngModel)]="email" required><input name="password" type="password" [(ngModel)]="password" required><button type="submit">Sign in</button></form><p>{{ error() || auth.error() }}</p></main>`
})
export default class SignInPage {
  email = '';
  password = '';
  readonly error = signal('');

  constructor(readonly auth: AuthService, private readonly router: Router) {}

  async submit(): Promise<void> {
    const error = await this.auth.signIn(this.email, this.password);
    if (error) {
      this.error.set(error);
      return;
    }
    await this.router.navigateByUrl('/radar');
  }
}
