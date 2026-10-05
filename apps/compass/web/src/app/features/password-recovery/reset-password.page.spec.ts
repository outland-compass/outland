import { describe, expect, it } from 'vitest';

import { newPasswordProblem } from './reset-password.page';

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
