# OUTLAND World V0

Private, visitor-facing OUTLAND World experience. This application remains a
thin presentation and onboarding layer; it does not own OUTLAND OS domain
truth.

## Required environment variables

- `WORLD_ACCESS_KEY_HASH` — SHA-256 hash of the normalized visitor access key.
- `WORLD_SESSION_SECRET` — random secret used to sign the HttpOnly visitor session.

Both values must be configured in Vercel for Preview and Production.

## Vercel project settings

- Framework preset: `Next.js`
- Root directory: `apps/world/web`
- Output directory: Next.js default
