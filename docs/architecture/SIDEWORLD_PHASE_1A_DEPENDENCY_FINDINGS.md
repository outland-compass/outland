# Phase 1A — additional dependency evidence (2026-10-02)

Read-only checks; no production DDL.

## GitHub source checks
- Inspected `apps/compass/web/src/app/core/compass/compass.repository.ts` (335 lines): no direct legacy universe or passport references in this file.
- Inspected `apps/world/web/app/explore/experience.tsx`, `app/access-gate.tsx`, `lib/session.ts`: experience is a local-state Passport concept, no direct legacy database queries in inspected files.
- Inspected generated `apps/compass/web/src/app/core/supabase/database.types.ts`: no direct legacy model references in checked file.
- `supabase/tests/verify-schema.sql` requires legacy tables and GREENHILL node; change it in the same staged release as actual cleanup, not before.
- `supabase/tests/verify-workflow-security.sql` has no direct legacy table-name references.
- Historical migration files are immutable; never delete or rewrite them just to remove old tables.

## Additional live production catalog check
- Four Passport FKs: `passport.journeys.node_id`, `passport.events.node_id`, `passport.events.frontier_id`, `passport.events.spot_id`.
- Internal legacy FKs: `universe.frontiers.node_id`, `universe.spots.frontier_id`.
- Three legacy `set_updated_at` triggers on nodes/frontiers/spots.
- No direct legacy references returned by the checked view search; this does not prove absence of all dynamic SQL or external clients.
- Production migration list matches the 16 expected historical versions. PR #27 is merged; its notes explicitly say isolated local reset, verification SQL and backup restore were NOT confirmed.

## Remaining blockers before destructive SQL
1. Confirm deployed Vercel code and external consumers, Edge Functions and integrations, plus broader function/policy/dependency audit.
2. Validate a restored backup and clean migration replay on isolated database.
3. Add and test canonical `infrastructure.bases` and source-UUID mapping; verify GREENHILL metadata parity.
4. Adapt Passport FKs and tests; run security/regression checks; prepare independent rollback.
5. Obtain separate explicit approval for destructive production cleanup.
