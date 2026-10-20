import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';

import { AuthService, RESET_PASSWORD_PATH } from './auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  // A recovery session may only set a new password; it does not open COMPASS.
  if (auth.recoveryMode()) {
    return router.parseUrl(RESET_PASSWORD_PATH);
  }
  return auth.session() ? true : router.createUrlTree(['/sign-in']);
};
