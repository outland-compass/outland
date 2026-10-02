# Dependency security remediation — verification plan

Status: in progress. This document records the user-supplied `npm audit --omit=dev` findings from 2026-10-02; do not treat dependency fixes as verified until fresh audit and tests pass.

## Baseline
- `apps/world/web/package.json`: Next.js pinned to `16.2.3`, React `19.2.4`. User's npm audit reports Next.js critical, and transitive PostCSS and Sharp high.
- `apps/compass/web/package.json`: Angular runtime packages `^22.1.0`; user's npm audit reports Angular Router high.
- Existing tests before dependency changes: Compass 36 passing; World 2 passing. Both production builds passed. This is **baseline**, not post-upgrade evidence.

## Planned patch
1. In a clean checkout of this branch, update Next.js to an audited fixed stable version (audit output suggested `16.3.8`), keeping Next.js and its lockfile in sync. Review any compatibility changes.
2. Update all Angular runtime and build/compiler packages as a coherent compatible patch set with a fixed Router release (at least `22.2.0` per reported advisory, subject to npm registry availability and compatibility).
3. Regenerate and commit the root `package-lock.json` using npm; do not hand-edit transitive package versions.
4. Confirm PostCSS and Sharp resolved versions with `npm ls next postcss sharp @angular/router`, and rerun `npm audit --omit=dev`. Do not assume transitive issues disappear merely because direct versions changed.
5. Run `npm test`, `npm run test:world`, `npm run build:world`, and `npm run build` with required Compass environment variables provided locally (never commit secrets). Review production build changes.
6. If available, run local DB verification separately; dependency updates should not introduce migrations.
7. Review GitHub/Vercel preview checks before marking the PR ready. No production deployment or merge until verification.

## Security handling
Do not run `npm audit fix --force` blindly. Inspect `npm audit --json` and the lockfile diff for unintended major changes. Do not commit generated `apps/compass/web/src/environments/environment.prod.ts` or secrets.
