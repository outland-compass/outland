# SIDEWORLD Schema V3.2 foundation — local validation

**Date:** 2026-10-06
**Scope:** local, disposable Supabase stacks only.
**Production and staging were NOT modified.** No `db push`, no remote CLI call, no link (`supabase/.temp/project-ref` absent).

| Item | Value |
| --- | --- |
| Branch | `feat/sideworld-schema-v3-2-foundation` |
| Base commit | `f6ec8a7ebc44b1027a86d9219877e70cf444636a` (current `main`, merge of PR #31); `git merge-base HEAD main` = `f6ec8a7` |
| Supabase CLI | 2.119.0 (`npx --yes supabase@2.119.0`), PostgreSQL 17 local stack |
| Migrations | 23 = 19 existing + 4 new (`202610060001`–`202610060004`). `migration list --local`: all 23 applied (`local` = `remote`). |

The ledger statements of the 4 new migrations match the current files under whitespace/comment/semicolon normalisation. Control: `20261004140102` matches the same way. So the local database was built from these exact files, not from an earlier draft.

## SQL verification

These ran with `psql -X -v ON_ERROR_STOP=1` in the local Postgres container, fail-fast:

| Suite | Result |
| --- | --- |
| `verify-schema.sql` | PASS |
| `diagnose-compass-promotion.sql` | PASS |
| `verify-workflow-security.sql` | PASS |
| `verify-sideworld-bases.sql` | PASS |
| `verify-sideworld-universe.sql` | PASS |
| `verify-sideworld-geo.sql` | PASS |
| `verify-sideworld-canon.sql` | PASS |
| `verify-sideworld-boundaries.sql` | PASS |

The four new suites run inside `begin … rollback` and leave no data behind.

## Database CI timelines (simulated locally)

The four Database CI jobs were run from the **modified** `.github/workflows/database-ci.yml`:
- each `run` step was extracted verbatim and executed;
- they ran on a separate disposable stack (`outland-ci`, own ports), never against the working stack;
- the only substitutions were the pinned CLI and the container filter.

| Job | Result |
| --- | --- |
| `local-migration-replay` (clean replay + seed, 8 suites) | PASS |
| `existing-data-upgrade` (pre-1B data → 1B → cleanup drill → cleanup → V3.2, 5 suites) | PASS |
| `staging-history-rehearsal` (8-migration staging history → catch-up → 1B + cleanup → V3.2, 5 suites) | PASS |
| `legacy-world-canon-upgrade` (pre-#27 canon → all pending incl. V3.2, 8 suites in `legacy_compatible`, strictness guards) | PASS |

**Why the workflow had to change:**
- The upgrade jobs held back only the 1B and cleanup migrations, so the new `20261006000*` files stayed in place and were applied by the initial `db reset`, before 1B and the cleanup.
- With the unmodified workflow, `existing-data-upgrade` **fails** in its prepare step (reproduced locally).
- The jobs now hold V3.2 back and apply it last, in history order. The four new suites run only after V3.2 is applied.

## DB types

`npm run db:types` runs an unpinned `npx supabase gen types typescript --local` without `--schema`. It produced a file containing only `graphql_public`: it **dropped `land`, `shared` and `public`**. This is a regression of the script, not of this branch.

That output was **not accepted**, and `database.types.ts` is unchanged (restored from `HEAD`).

Investigation with `supabase@2.119.0 gen types typescript --local --schema land,public,shared`:
- `universe`, `geo` and `canon` do **not** appear.
- Compared object by object (tables, views, functions, enums) with the committed file, the only difference is `land.mobile_candidate_specs`. That table is missing from the committed types and comes from the earlier migration `20260912141712`, so it is pre-existing drift unrelated to this branch.
- The other textual differences come from the generator version: `never` for generated columns, quoting, `__InternalSupabase`.

## Application regression

| Check | Result |
| --- | --- |
| `npm test` | PASS: 5 files, 36 tests |
| `npm run typecheck` | PASS |
| `npm run build` | PASS |

`npm run build` ran with the Web CI placeholders (`SUPABASE_URL=https://example.supabase.co`, `SUPABASE_PUBLISHABLE_KEY=ci-placeholder-publishable-key`). The tracked `environment.prod.ts` it rewrites was restored afterwards. The only warning is the pre-existing `mobile-assets.page.scss` budget (4.39 kB > 4 kB).

## Git diff summary

Tracked files modified:
- `.github/workflows/database-ci.yml` (+21 −6): V3.2 held back and applied last in the three upgrade jobs; the 4 new suites added where V3.2 is applied.
- `CLAUDE.md` (+13 −7): V3.2 canonical guidance; `core.*` and `shared.worlds`-as-identity superseded; legacy cleanup recorded as closed.

New files:
- `supabase/migrations/202610060001_sideworld_universe_foundation.sql`
- `supabase/migrations/202610060002_sideworld_geo_foundation.sql`
- `supabase/migrations/202610060003_sideworld_universe_mapping.sql`
- `supabase/migrations/202610060004_sideworld_canon_foundation.sql`
- `supabase/tests/verify-sideworld-universe.sql`, `verify-sideworld-geo.sql`, `verify-sideworld-canon.sql`, `verify-sideworld-boundaries.sql`
- `docs/architecture/SIDEWORLD_SCHEMA_V3_2_CANONICAL_ARCHITECTURE.md`
- `docs/architecture/SIDEWORLD_SCHEMA_V3_2_LOCAL_VALIDATION.md` (this report)

These are unchanged: historical migrations, `supabase/seed.sql`, `supabase/config.toml`, `database.types.ts` and Compass application code.

## Architecture boundary verification

- **`shared.worlds`:** not renamed, repurposed, deleted or repointed. The new migrations only reference it from `universe.world_outland_map.outland_world_id` (FK, `on delete restrict`) and in comments.
- **`universe.world_outland_map`:** explicit, optional 1:1 bridge (`world_id` PK, `outland_world_id` unique). No automatic backfill.
- **Existing dependencies:** `infrastructure.bases` still references `shared.worlds`, and no `land` FK references `universe.worlds`. Both are checked by `verify-sideworld-boundaries.sql`.
- **Untouched objects:** `land.*`, `shared.activities`, `passport.journeys/events`. No `places.base` exists.
- **Private schemas:** `universe`, `geo` and `canon` are private. Verified in the catalog:
  - `anon`, `authenticated` and `service_role` have no schema USAGE and no table DML on any of them;
  - every table has RLS enabled;
  - `api.schemas` remains `public, graphql_public, shared, land`.
- **`universe.set_updated_at()`:** retained.
  - Migration `0001` revokes schema privileges on `universe`, now also from `service_role`.
  - No API role can insert or update `passport.journeys/events`, so the Passport trigger path is unaffected.
- **Updated-at triggers:** the new tables use the existing `public.set_updated_at()`.

## Remaining risks and open points

1. The headers of all four new migrations still say `STATUS: DRAFT ONLY. NOT EXECUTED.` That is misleading once committed. Changing it is a comment-only edit to the new files and needs a quick local re-replay.
2. Each new migration wraps itself in explicit `begin; … commit;`.
   - The CLI appends its ledger insert after the file's COMMIT, so the ledger row is written in its own implicit transaction instead of atomically with the DDL.
   - Low risk: local replay and all CI timelines pass. Consider removing the explicit wrappers before any remote deployment.
3. `npm run db:types` is broken (unpinned CLI, no `--schema`), and the committed types already drift (`land.mobile_candidate_specs`). This is pre-existing and out of scope; it needs its own fix.
4. Deployment is not in scope. On a remote target, creating `universe.world_outland_map` adds an FK to `shared.worlds`, which briefly takes a `SHARE ROW EXCLUSIVE` lock on it. Staging and production deployment need a separate approval, a backup, a rehearsal and a runbook.
5. The new suites check structure and privileges on empty tables. They do not exercise future data flows: Studio access, published consumer contracts and `signal`.
