# AI Puzzle Provider Integration — Activation Checklist

**Status:** Interface implemented; no live provider connected. No database migration or production deployment in this change.

## Implemented boundaries
- `production-manifest.ts` prepares verified public location and supported fact inputs.
- `puzzle-mechanics.ts` defines versioned puzzle types and candidate validation.
- `puzzle-generation.ts` builds bounded generation requests and rejects malformed, out-of-context outputs.
- `puzzle-provider.ts` accepts an injected provider, applies per-request limits, and returns **draft-only** candidates.

## Required before enabling any real model calls
1. Select a provider/model and inspect existing deployment configuration and secrets handling. Keep credentials server-side only.
2. Implement a server-only provider with enforced request cancellation, actual model output token cap, explicit model/version, and strict JSON output.
3. Estimate input tokens **before** calling the provider and reject over-budget requests. Current post-response usage validation is not a pre-call spending guarantee.
4. Add rate limits, authenticated owner permissions, per-universe daily/monthly spending caps, idempotency and structured redacted audit logs. Do not log hidden accepted answers in player-facing telemetry.
5. Add integration tests using a fake provider: successful draft, malformed JSON, timeout, exceeded budget, untrusted IDs, duplicate candidates and provider errors.
6. Add human editorial review; do not expose answers in the mobile player payload. Field QA remains mandatory.
7. Audit production schema, migrations, RLS and applications before proposing any persistence changes. Production database changes require explicit approval.

## Rollout
Keep AI generation disabled by default behind a dedicated feature flag. Enable for an owner-only test universe after security and cost checks. Preview deployment is not evidence that generation works.

## Caveats
This module validates references and structure, not puzzle creativity, pedestrian safety, clue solvability, or actual source truth. Model output is untrusted. The generated draft status is never equivalent to editorial or field verification.
