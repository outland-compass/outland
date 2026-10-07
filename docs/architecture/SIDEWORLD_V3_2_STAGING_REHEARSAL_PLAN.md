# SIDEWORLD Schema V3.2 — Staging Rehearsal Plan

**Status:** PREPARED / LOCAL RE-DRILL REQUIRED BEFORE LIVE PREPARE  
**Target:** staging `clgpxvyflycudzhdzjlv` only  
**Production:** `huzcukdovavejejwohey` is explicitly out of scope and rejected by the tooling  
**Current repository baseline:** `main` at `2683c548a1c5d28b458f1b84aa84602aebae4957` (merge of PR #35)  
**Atomicity decision:** approved Option B — the four V3.2 migration files are wrapperless and are executed in one outer `psql -1` transaction.

## 1. Migration identity

The operator tooling pins Git blob IDs, because they are invariant across Windows working-tree line-ending conversions. SHA-256 below is of the committed GitHub UTF-8/LF content and is secondary evidence.

| Migration | Git blob | SHA-256 (committed LF content) |
| --- | --- | --- |
| `202610060001_sideworld_universe_foundation.sql` | `108ced4d481f90990650d9f041bb74b0eac95cff` | `eb9d5e37b77134e742c9ad6fd1a0b2cd82350a26cf803d413b4045c52393efc5` |
| `202610060002_sideworld_geo_foundation.sql` | `b06b95ca8d4dc6fe461a4bd73dbfbb3e314b09a9` | `4436980e29745401682f4ec4a53e423f6f468ac8b0378b84f4df13cfec43ffeb` |
| `202610060003_sideworld_universe_mapping.sql` | `770723c9c973800deb2db18ee2fc959eb137dbf7` | `6e2718047c37855d5b9f25b178b5a2e2c299d5e4d07ddbbbf0bfe1069da74d52` |
| `202610060004_sideworld_canon_foundation.sql` | `9830e8496f3189c8356920160d23a9259fd7c56c` | `fed86f3879d0e4b09f2adf55c60a0eea677373cb3acbff55f248784fd3f83c90` |

The eventual staging execution must use an **explicit `-SourceSha` equal to the reviewed/merged tooling commit**, not merely the current `2683c54` baseline. This avoids needing to edit the script again after the tooling PR is merged.

## 2. Live staging baseline — independently verified read-only

A read-only audit on 2026-10-07 verified the current staging baseline. This does **not** replace the future `Prepare` step; `Prepare` must create a fresh backup and re-check freshness immediately before any Execute.

Verified:

- staging project: `outland-staging`, ref `clgpxvyflycudzhdzjlv`, healthy;
- migration ledger: **19 versions**, latest `20261004140102_retire_legacy_universe_v0`;
- `universe.set_updated_at()` exists;
- legacy `universe.nodes`, `universe.frontiers`, `universe.spots` do not exist;
- V3.2 `universe.universes`, `universe.worlds`, `geo.countries`, `canon.franchises` do not exist;
- `infrastructure.bases.world_id -> shared.worlds.id` remains intact;
- `passport.journeys/events` still reference `shared.worlds`;
- `passport_journeys_set_updated_at` still calls `universe.set_updated_at()`;
- API roles have no `USAGE` on `universe`, `passport`, or `infrastructure`; `shared` and `land` remain accessible as before;
- PostgREST exposure remains `public, graphql_public, shared, land`; `universe`, `geo`, `canon` are not exposed.

Observed staging row counts:

| Object | Rows |
| --- | ---: |
| `shared.worlds` | 8 |
| `land.candidates` | 13 |
| `shared.activities` | 23 |
| `infrastructure.bases` | 1 |
| `infrastructure.base_legacy_migration_audit` | 1 |
| `passport.journeys` | 0 |
| `passport.events` | 0 |

The authoritative deployment-time preservation evidence remains the fresh backup/fingerprint set produced by `Prepare`, not these historical counts.

## 3. Tooling files

Under `scripts/staging/sideworld-v3-2/`:

- `deploy-staging-v3-2.ps1` — operator entry point (`Prepare`, `Execute`, `CompleteLedger`);
- `preflight.sql` — read-only exact-baseline gate;
- `fingerprints.sql` — read-only preserved-data/privilege fingerprints;
- `apply-atomic.sql` — **only apply path**; all four wrapperless migrations under one `psql -1` transaction;
- `committed-state-check.sql` — read-only guard used after schema commit and before/through ledger recovery;
- `post-validate.sql` — read-only final schema/ledger/boundary validation;
- `rollback-empty.sql` — separately approved empty-state rollback only;
- `structure.sql` — diagnostic structural fingerprint helper (not a deployment gate);
- `cli-output.lib.ps1` — CLI output parsing helper.

Existing shared tooling reused:

- `scripts/staging/backup-staging.ps1` — read-only backup plus optional fingerprints;
- existing `staging-session.ps1`, `verify-backup.ps1`, `inventory.sql` from the repository.

## 4. Prepare — read-only only

Future command, after the tooling PR is merged and a clean detached deployment checkout exists:

```powershell
powershell -ExecutionPolicy Bypass -File C:\deploy\outland-sideworld-v3-2\scripts\staging\sideworld-v3-2\deploy-staging-v3-2.ps1 `
  -Mode Prepare `
  -SourceSha <APPROVED_TOOLING_MERGE_SHA>
```

Prepare must pass all gates:

1. checkout HEAD exactly equals the explicit `-SourceSha`;
2. checkout is unlinked and clean;
3. exactly 23 migration files are present;
4. the four V3.2 files match the pinned Git blob IDs;
5. approved atomicity commit `e8634721dc46cb6735e320a441ec45eb8bc5167c` is an ancestor and its Database CI succeeded;
6. target URL is exactly staging and cannot contain the production ref;
7. fresh staging backup succeeds and `verify-backup.ps1` passes;
8. staging baseline is exactly the expected 19 versions, latest `20261004140102`;
9. legacy cleanup is complete; helper/Passport trigger intact; no V3.2 objects already exist;
10. staging-specific world canon guard passes (`RIVERKEEPER` present, `RAFTER` absent);
11. fresh live fingerprints equal the just-created backup fingerprints;
12. API exposure remains `public, graphql_public, shared, land`;
13. `db push --dry-run` lists exactly migrations `202610060001..0004`, in order;
14. no staging write is performed.

A successful result is `PREPARED`. It is **not** authorization to Execute.

## 5. Execute — separately approved staging write

Execute requires separate written founder approval naming the exact tooling merge SHA and a quiet window with COMPASS writes paused.

```powershell
powershell -ExecutionPolicy Bypass -File C:\deploy\outland-sideworld-v3-2\scripts\staging\sideworld-v3-2\deploy-staging-v3-2.ps1 `
  -Mode Execute `
  -SourceSha <APPROVED_TOOLING_MERGE_SHA>
```

The operator must type:

`APPLY-V32-STAGING-clgpxvyflycudzhdzjlv`

Apply sequence:

1. Re-run every Prepare gate with a new fresh backup.
2. Re-check HEAD/clean state and all four pinned migration blobs immediately before writing.
3. Refuse execution if any migration contains a top-level `BEGIN` or `COMMIT` wrapper.
4. Run `apply-atomic.sql` with `psql -1`:
   - one outer transaction for all four migrations;
   - `statement_timeout = 60s`;
   - `lock_timeout = 5s`;
   - exact 19-version ledger guard before DDL;
   - all four migration bodies in order;
   - 18-table count guard before commit;
   - ledger is untouched inside the schema transaction.
5. If any SQL statement fails, the whole V3.2 schema transaction rolls back; staging remains at the 19-version schema/ledger baseline.
6. After a successful commit, run `committed-state-check.sql` **before touching the ledger**.
7. Repair the four migration versions one at a time, in order. This makes a CLI/connection failure explicitly recoverable.
8. Run final post-validation, read-only SQL suites, preserved-data fingerprint comparison, API exposure check and CLI up-to-date check.

The brief FK creation lock on existing `shared.worlds` is bounded by `lock_timeout = 5s`. Execute should occur only in a quiet window.

## 6. Ledger-repair failure window and deterministic recovery

There is one deliberate, bounded gap: the atomic schema transaction can commit successfully before all four Supabase migration ledger rows are recorded.

If any `migration repair --status applied` call fails:

- **do not run `db push`;**
- **do not re-run the schema migrations;**
- record the evidence directory and stop;
- use `CompleteLedger` only after explicit recovery approval.

Recovery command:

```powershell
powershell -ExecutionPolicy Bypass -File C:\deploy\outland-sideworld-v3-2\scripts\staging\sideworld-v3-2\deploy-staging-v3-2.ps1 `
  -Mode CompleteLedger `
  -SourceSha <THE_SAME_APPROVED_TOOLING_MERGE_SHA>
```

`CompleteLedger`:

1. re-verifies the pinned clean checkout and staging target;
2. runs `committed-state-check.sql` read-only;
3. requires exactly the 18 expected empty/private V3.2 tables, exact 25 V3.2 FKs, 13 expected `updated_at` triggers, RLS on all 18, no RLS policies, no API-role grants, no OUTLAND-to-V3.2 FK, and only baseline+V3.2 ledger versions;
4. determines exactly which of the four V3.2 versions are missing;
5. requires typed confirmation `COMPLETE-V32-LEDGER-STAGING-clgpxvyflycudzhdzjlv`;
6. repairs **only** missing versions, in canonical order;
7. re-runs the committed-state guard after each ledger repair;
8. finishes with `post-validate.sql` requiring the complete 23-version ledger.

This path never re-applies schema DDL.

## 7. Post-validation

Required default read-only suites:

- `verify-schema.sql` in `legacy_compatible` mode;
- `verify-sideworld-bases.sql`;
- `verify-sideworld-universe.sql`;
- `verify-sideworld-geo.sql`;
- `verify-sideworld-canon.sql`;
- `verify-sideworld-boundaries.sql`.

The two write-path suites remain **opt-in only** and should be OFF for the first staging rehearsal unless separately approved:

- `verify-workflow-security.sql`;
- `diagnose-compass-promotion.sql`.

Final requirements include:

- 23 migration versions, each V3.2 version exactly once;
- exactly 18 new V3.2 tables;
- RLS on every new table, no policies/grants for API roles;
- all new foundation tables empty;
- `universe/geo/canon` still absent from Compass API exposure;
- `shared.worlds`, `infrastructure.bases`, `land.*`, `shared.activities`, Passport objects and preserved data unchanged;
- `universe.world_outland_map` is the only V3.2 bridge to `shared.worlds`;
- `universe.set_updated_at()` and the Passport trigger remain intact;
- `db push --dry-run` reports the database up to date.

## 8. Empty-state rollback — separate approval only

`rollback-empty.sql` is never automatic.

It is allowed only while all 18 new V3.2 tables are empty. It:

- runs in one transaction with 60s statement / 5s lock timeouts;
- locks the 18 new tables first;
- refuses if any new table has rows;
- refuses unexpected relations/functions/dependencies;
- uses `RESTRICT`, never `CASCADE`;
- drops only the V3.2 tables and `geo`/`canon` schemas in reverse dependency order;
- retains `universe` schema, `universe.set_updated_at()` and the Passport trigger;
- restores the post-cleanup `universe` schema comment.

Only after schema rollback succeeds may the four ledger versions be marked reverted. If any V3.2 table has data, destructive rollback is **not** the default; prefer a forward fix and require separate data-export/data-loss approval for any destructive action.

## 9. Local validation history and required re-drill

Before PR #35, the package was drilled end to end locally, including backup, Prepare, Execute, fingerprints, rollback/reapply, failure injection and production-ref refusal. PR #35 then changed the four migration files by removing their top-level transaction wrappers, and the atomic failure drill independently passed.

This updated package changes the operator logic to atomic-only and adds explicit `CompleteLedger` recovery. Therefore, **one more end-to-end local disposable-stack drill is required before the tooling is committed/merged and before live Prepare**. The drill must include:

1. 19-version staging-shaped baseline;
2. Prepare PASS;
3. atomic Execute PASS;
4. all default read-only suites PASS;
5. fingerprints/API unchanged;
6. empty rollback + ledger revert returns to baseline;
7. reapply PASS;
8. injected failure late in migration 4 leaves zero V3.2 objects and ledger 19;
9. simulated post-schema-commit ledger failure, then `CompleteLedger`, completes only missing ledger rows without reapplying DDL.

## 10. Remaining gates before live staging Prepare

1. Run the local re-drill above on the updated package.
2. Review the resulting diff and evidence.
3. Commit the tooling/docs on a dedicated branch and open a PR.
4. CI/review the tooling PR and merge it.
5. Create clean detached deployment worktree at that **tooling merge SHA**.
6. Run live `Prepare` read-only with that SHA.
7. If and only if Prepare is `PREPARED`, schedule a quiet window and issue a separate written staging Execute approval.

No production action is part of this plan.
