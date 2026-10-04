# SIDEWORLD Phase 1B — staging-snapshot rehearsal evidence (2026-10-03)

Sanitized evidence from the local rehearsal of the ten pending staging migrations against a restored
snapshot of `outland-staging` (`clgpxvyflycudzhdzjlv`). This file contains identifiers, hashes, versions
and test results only. It contains no credentials, no backup files, and no candidate or world business data.

**Scope:**
- Nothing was deployed to staging. Production was not contacted.
- Staging was accessed once, for a read-only export: `pg_dump`, `supabase db dump` and a `READ ONLY` inventory transaction.
- All writes happened in a disposable local Supabase stack, which was destroyed afterwards (0 containers and 0 volumes remain).

**Code under test:**
- The 8 historical migrations come from `main@c5c2282`.
- The 2 SIDEWORLD migrations and the PR tests come from PR #29 at `0ec4221`.
- The later commit `1532075` changes documentation only, so the migration and test files are byte-identical at the current head.

## 1. Backup integrity

| Item | Evidence |
| --- | --- |
| Backup | Taken 2026-10-03 20:24 UTC, PG 17.6. Contains roles, schema, data (COPY), a full custom-format dump, a read-only inventory and `SHA256SUMS`. Stored outside Git with an owner-only ACL. |
| Integrity check | 28/28 PASS, run three times; the last run was after the final teardown. Covers SHA-256 of all 10 files, `pg_restore --list` (the dump contains `schema_migrations`, `land.candidates` and `shared.worlds` data) and the inventory cross-check. |
| SHA-256 `staging-full.dump` | `914f9fe44d43a5071e96d6dfd30ef05863fbc9def02dd96a3704905b62da51f0` |
| SHA-256 `schema.sql` / `data.sql` / `roles.sql` | `eda1a7cf…37e9` / `f7f795fc…b371` / `0decd601…da3a` |
| Sensitive content | 0 `auth.users`, 0 sessions, 0 vault rows. `roles.sql` holds role settings only, with no passwords. |
| Restore fidelity | Four independent restores. Worlds, candidates and migration-ledger inventories are byte-identical to the live staging inventory (row md5 and full JSON). |
| Restore time (disposable stack) | 40–44 s: stack start plus 2 s of restore. Restoring the hosted staging project was **not** measured. |

Restore procedure (local stack):
1. Run `roles.sql`, then `schema.sql`, then `SET session_replication_role = replica`, then `data.sql`. Use one transaction, as `supabase_admin`.
2. Restore `supabase_migrations` with `pg_restore -n supabase_migrations` from the full dump. The Supabase data dump does not include it.
3. Start the local stack with an **empty** `supabase/migrations/` folder, because `supabase start` auto-applies any files present.

## 2. Migration ledger (ten versions)

**Baseline on the snapshot (8):** `202608180001`, `202608180002`, `202608180003`, `202608180004`, `202608200001`, `202608210001`, `202609020001`, `202609030001`. These are identical to the live staging inventory.

**Applied one at a time** with `supabase@2.119.0 migration up --db-url <local>`, in lexicographic filename order:
- `apply s` is wall time, including about 2.4 s of CLI start-up per call.
- `stmts` and `stmts md5` come from `supabase_migrations.schema_migrations.statements` after the apply.

| # | Version | Name | Source | git blob | file SHA-256 | Exit | Apply s | Stmts | Stmts md5 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `20260912141712` | wanderer_mobile_radar | main + PR | `78899a9` | `ad16db04…8b19` | 0 | 2.50 | 8 | `eb12f3b8…` |
| 2 | `20260912141742` | wanderer_benchmark_image | main + PR | `bf30ca2` | `605ba7f8…2dcc` | 0 | 2.52 | 1 | `08e291f8…` |
| 3 | `20260912145301` | wanderer_decision_layer | main + PR | `8daf4e6` | `d7663c0f…2485` | 0 | 2.83 | 8 | `92b5a5dc…` |
| 4 | `20260913141314` | universe_v0_core_and_passport_journey | main + PR | `da4d21c` | `fd734290…e0c0` | 0 | 2.77 | 45 | `3c73ef1d…` |
| 5 | `20260913141954` | greenhill_universe_node_v0 | main + PR | `2472640` | `2048959a…0831` | 0 | 2.48 | 1 | `f2378365…` |
| 6 | `20260917110721` | pod_radar | main + PR | `9a11e80` | `d1e566c2…27e8` | 0 | 2.61 | 27 | `a6a851bd…` |
| 7 | `202609190001` | discovery_signal_promotion | main + PR | `d6b157b` | `6b70c0d7…f758` | 0 | 2.57 | 3 | `0bf86585…` |
| 8 | `20260919100334` | add_poseljani_pod_radar_signal | main + PR | `0e06002` | `ce130487…27cb` | 0 | 2.85 | 1 | `8d0e7a7e…` |
| 9 | `202610020001` | sideworld_bases_foundation | PR only | `c788e22` | `dd28012f…0378` | 0 | 2.86 | 5 | `055d3e0f…` |
| 10 | `202610020002` | sideworld_bases_legacy_backfill | PR only | `73bd6da` | `0e7b393b…0d05` | 0 | 2.65 | 4 | `efe26723…` |

The final ledger has 18 versions. Two independent full runs gave the same result.

**Pre-SIDEWORLD guard state** after #8: 1 `universe.nodes` row, of type `stay` (GREENHILL N.01). `frontiers`, `spots`, `passport.journeys` and `passport.events` were all empty.

## 3. The seven existing candidates (before → after)

- **Hashes:** `md5(to_jsonb(row))`. "Staging" is the live read-only inventory; "Before" is the restored snapshot; "After" is the state after all ten migrations. The after-hash leaves out the one column added by `pod_radar` (`development_model`, which defaults to `UNDECIDED`).
- **World:** every candidate's `world_id` = `edbd3bf4-45e7-4a38-9b3c-0455a0627fb7` (`OUTLAND_WORK`) on staging, before and after.

| Candidate ID | Staging = Before | Before = After |
| --- | --- | --- |
| `4ae0bac7-3e53-45f2-9a45-6a2cca8e81f6` | `652f1c8a…` ✔ | ✔ |
| `7a740883-7d0e-400b-b753-2dd6486c9fe8` | `43334e9e…` ✔ | ✔ |
| `9fcd4057-90c2-4ad0-a3d1-3e5560c74eee` | `5aa7f341…` ✔ | ✔ |
| `a1df1c88-4a6a-48fe-bae5-b06e89f6ecc0` | `bfb12908…` ✔ | ✔ |
| `b9510a64-e94c-412d-ba04-7a574411e58f` | `69d1941d…` ✔ | ✔ |
| `df36ab39-6d3b-4147-801d-7fdb1c77b01b` | `a732dde9…` ✔ | ✔ |
| `fb315874-e63f-42eb-bd28-8d06e8b93fbe` | `b52efec7…` ✔ | ✔ |

**Per-column check:** 0 candidates missing, 0 world links changed, 0 original column values changed, 0 dangling world references. Every single-column foreign key that points at `land.candidates` showed no change in the related row counts of these seven candidates.

**Worlds:** all 8 are present with unchanged IDs and codes. Only `WANDERER` changed, in exactly the columns `wanderer_mobile_radar` sets: `radar_enabled`, the target capital and reunderwrite fields, `target_profile`, `search_notes` and `updated_at`.

**Additions:**
- 6 candidates: 5 Pod candidates with a NULL world, and the WANDERER benchmark.
- WANDERER configuration: 9 criteria, 10 gates and 5 weights.
- 1 GREENHILL universe node and 1 base.

## 4. SIDEWORLD objects

- **Bases:** `infrastructure.bases` has 1 row. Its `world_id`, `asset_id`, `name`, `status`, `metadata`, `created_at` and `updated_at` equal those of source node `4ce78c43-c0a4-4458-a795-0a0c8804e1e8`.
- **Audit:** `infrastructure.base_legacy_migration_audit` has 1 row, with `source_snapshot = to_jsonb(node)` exactly. There are no orphans, and the node, audit and base counts are all 1.
- **RLS:** enabled on both tables, with 0 policies. `anon`, `authenticated` and `service_role` have no schema USAGE and no table privileges, so access is denied by default and **no application access is enabled in this phase**.
- **Legacy tables:** `universe.*` and `passport.*` are unchanged.

## 5. Verification tests (restored snapshot, after all ten migrations)

### Current results: test compatibility in `119432c` (supersedes the table below)

**Change:**
- `verify-schema.sql` and `verify-workflow-security.sql` resolve the floating world through `pg_temp.resolve_floating_world()`.
- **Default mode `canonical`** (clean installs; the setting is unset in the CI clean replay): the world **must** be code `RAFTER`. The assertions are unchanged.
- **Opt-in mode `legacy_compatible`** (`set outland.world_canon = legacy_compatible`, or `PGOPTIONS`):
  - RAFTER is used if it exists.
  - Otherwise, the single existing world with the floating River/GUARDIAN/FLOW profile is resolved. That is staging's `RIVERKEEPER`, `3fa8b58a…`, resolved by profile, never hardcoded.
  - RAFTER coexisting with another world of that profile is rejected as ambiguous.
- No security, gate or promotion assertion was removed or relaxed. No world record is created or changed.

| Suite (at `119432c`) | Staging snapshot, `legacy_compatible` | Staging snapshot, `canonical` |
| --- | --- | --- |
| `verify-schema.sql` | **PASS** (RIVERKEEPER by profile) | **FAIL, as intended**: `RAFTER floating Compass world missing` |
| `verify-workflow-security.sql` | **PASS** (RIVERKEEPER by profile; full security suite, rolled back) | **FAIL, as intended**: `Required test worlds missing` |
| `diagnose-compass-promotion.sql` | **PASS** | n/a (no world canon dependency) |
| `verify-sideworld-bases.sql` | **PASS** | n/a |
| Ambiguity guard (RAFTER inserted next to RIVERKEEPER, rolled back) | **Rejected as intended**: `Ambiguous floating world`; 0 RAFTER rows afterwards | n/a |

After all of these runs, the world records and the 7 candidates were unchanged (re-run comparison: 0 changes).

**GitHub Database CI run `37155548122` on `119432c`: success, 4/4 jobs:**
- `local-migration-replay` (clean install, **canonical**): `verify-schema`, `diagnose-compass-promotion` and `verify-workflow-security` all PASS, with no legacy resolution.
- `existing-data-upgrade`: PASS.
- `staging-history-rehearsal`: PASS.
- **New `legacy-world-canon-upgrade`:**
  - Builds the 8-version baseline, seeded with the pre-#27 `seed.sql`, as staging was, then catches up all 10.
  - All 4 suites PASS in `legacy_compatible` mode.
  - Canonical mode still rejects the legacy canon.
  - The ambiguous identity is rejected.

### Earlier results (tests before `119432c`)

| Test | Result |
| --- | --- |
| `verify-sideworld-bases.sql` (PR) | **PASS**: two full runs, after the failure-recovery run, after rollback and re-apply |
| `diagnose-compass-promotion.sql` (PR) | **PASS** |
| `verify-workflow-security.sql` (main, RIVERKEEPER fixture) | **PASS** |
| `verify-workflow-security.sql` (PR, RAFTER fixture) | **FAIL**: `Required test worlds missing` (no check runs) |
| `verify-schema.sql` (main = PR) | **FAIL**: `RAFTER floating Compass world missing or Radar disabled` |

### RAFTER discrepancy: test compatibility implemented in `119432c` (option b); the world canon is still unreconciled

- **Cause:**
  - `#27` (`26eb571`) changed `seed.sql` to match production's world codes, renaming `RIVERKEEPER` to `RAFTER` and `ALIKI` to `ORIGIN`.
  - Staging was seeded earlier and still holds `RIVERKEEPER` and `ALIKI`.
  - RAFTER is created only by `seed.sql`, never by a migration, so no migration path produces it.
- **Equivalence:** the staging `RIVERKEEPER` record is RAFTER under its legacy code. It has the same River / GUARDIAN / FLOW / FLOATING profile, the same Danube geography and the same 9 floating gates. Its capital targets differ.
- **Diagnostics** (scratch copies only; repo tests unchanged):
  - The PR's `verify-workflow-security` passes when its one RAFTER lookup is pointed at `RIVERKEEPER`.
  - `verify-schema` passes when its two seed-only RAFTER assertions are removed.
  - These are diagnostics, **not** green results.
- **Why no seed was run:** `seed.sql` upserts worlds `on conflict (code)`. On staging it would overwrite 6 existing world rows, including `OUTLAND_WORK`. It would also insert RAFTER and ORIGIN as **new UUIDs** next to RIVERKEEPER and ALIKI, creating duplicate canonical worlds. No seed was run, and no staging world record was modified.
- **Disposition:** option (b) is implemented in `119432c`. Staging's legacy world codes remain as they are. Reconciling them (option c: rename codes, preserve UUIDs) stays a separate, reviewed decision outside Phase 1B. Do not rename worlds as part of Phase 1B.

## 5b. Runbook drill (`SIDEWORLD_STAGING_DEPLOYMENT_RUNBOOK.md`, steps 3–8)

- **Setup:**
  - Run on a fresh restore of the staging snapshot.
  - Uses the committed `scripts/staging/*` files and the real deployment path (`db push --db-url` from an unlinked checkout).
  - Only three things differed from the runbook: the password prompt was scripted, the target was the local restore, and `--yes` was passed.
- **Results:**
  - Target check: `TARGET VERIFIED`.
  - Phase A dry-run and push: exactly the 8 historical versions, `"seeds":[]`.
  - Checkpoint: `CHECKPOINT PASSED` (16 versions, 1 stay node, no frontiers or spots).
  - Phase B: exactly the 2 SIDEWORLD versions.
  - Post-deployment: `POST-DEPLOY VALIDATION PASSED`. `verify-sideworld-bases` PASS; `verify-schema` and `verify-workflow-security` PASS with `-PreSql "set outland.world_canon = legacy_compatible"`, which works through the pooler.
  - Ledger: 18 remote, 0 local-only, 0 remote-only.
  - SIDEWORLD rollback: back to 16 versions, checkpoint passes again. Re-push and re-validation PASS.
  - The target check on a deployed DB correctly STOPs.
- **Bug found by the drill and fixed:** Windows PowerShell 5.1 turned `psql` NOTICEs on stderr into terminating errors under `$ErrorActionPreference = 'Stop'`. `Invoke-StagingSql` now treats native output as text and decides success only from `psql`'s exit code.
- **Observed:** `db push --db-url` treats the target as remote and requires TLS. That's correct for staging; the local drill used `sslmode=disable`.

## 6. Failure handling and rollback (tested locally)

| Case | Result |
| --- | --- |
| **F1:** backfill guard trips (a legacy frontier row was injected), with both SIDEWORLD versions pending | `migration up` exit 1, `Nonempty legacy frontier/spot tables`. **Per-migration atomicity confirmed:** `202610020002` was not recorded and its `base_legacy_migration_audit` table does not exist. `202610020001` **stayed committed** (`infrastructure.bases` present, ledger at 17). |
| F1 recovery | After removing the cause, re-running `migration up` applied only `202610020002`. Ledger at 18; `verify-sideworld-bases` PASS. |
| **F2a:** rollback from the complete state | PASS. Ledger at 16, `infrastructure` gone, legacy node intact, all 7 candidates unchanged. |
| Rollback exactness | The schema-only dump after rollback is identical to the dump after the 8 historical migrations on an independent fresh restore. The only difference is `pg_dump`'s random `\restrict` token. |
| **F2b/F2c:** rollback from the partial state (foundation only) | PASS (`IF EXISTS`). Ledger at 16. |
| F2d: roll forward after rollback | PASS. Ledger at 18; `verify-sideworld-bases` PASS; candidates unchanged. |
| **F2e:** rollback guard with an unexpected object in `infrastructure` | Aborts with `manual review`; nothing dropped and the ledger stays at 18. |

Rollback for the two SIDEWORLD versions. It runs in one transaction with no `CASCADE`, so any other dependent object blocks it. The base UUIDs are regenerated on re-apply.

```sql
begin;
do $$ begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'infrastructure' and c.relkind in ('r','v','m','p')
               and c.relname not in ('bases','base_legacy_migration_audit')) then
    raise exception 'infrastructure schema contains objects not created by SIDEWORLD 1B - manual review';
  end if;
end $$;
drop table if exists infrastructure.base_legacy_migration_audit;
drop table if exists infrastructure.bases;
drop schema if exists infrastructure;
delete from supabase_migrations.schema_migrations where version in ('202610020001','202610020002');
commit;
```

**Rollback limits:**
- The 8 historical migrations change data (seeding, upserts, `update shared.worlds`) and have no down scripts. To roll them back, **restore the verified backup**.
- A restore of the hosted staging project was not rehearsed, because it would write to staging, and it is slower than the local measurement.
- A failure partway through the 10-version batch leaves every earlier version committed. Recover by fixing the cause and re-running `up`, or by running the SIDEWORLD rollback above. For the historical versions, restore the backup.

## 7. Remaining risks

- **Production link:** the repository's Supabase CLI link points to **production**. Target staging only with an explicit `--db-url`; never use `--linked`.
- **Version ordering:** versions mix 12 and 14 digits, and only lexicographic filename order is correct. A numeric sort would put `202609190001`, `202610020001` and `202610020002` first, and they would fail.
- **Version gap:** the rehearsal used PG 17.11 with local platform services; staging runs 17.6. Concurrent application traffic was not simulated.
- **Backup transport:** the backup used `sslmode=require` without certificate verification.

## 8. Staging deployment execution record (2026-10-04)

**Result: DEPLOYED AND VALIDATED.**
- Target: `outland-staging` (`clgpxvyflycudzhdzjlv`) only. Production was not contacted.
- Executed from approved commit `63b0012839baa71c3922debaa4c3970b131333dd`, following `SIDEWORLD_STAGING_DEPLOYMENT_RUNBOOK.md` with the committed `scripts/staging/*`.
- Window: 2026-10-04 11:13:27 to 11:17:55 (+02:00).
- The operator entered the password at masked prompts and typed explicit confirmations for both write phases.

| Runbook step | Evidence |
| --- | --- |
| 1. Checkout | HEAD = approved SHA, not linked, clean, 18 migration files. Database CI on the SHA: success. |
| 2. Backup | New backup `staging-20261004-111328`, a read-only export at 09:14:42 UTC, PG 17.6. `verify-backup`: ALL CHECKS PASSED. `staging-full.dump` SHA-256 `0adc2c239c6d162fefed99dfe884af6417cbae5dc9d5db1734944b4fc0ae1310`. Its candidates, worlds and migration ledger are byte-identical to the rehearsed snapshot of 2026-10-03. |
| 3. Target | The URL is exactly the staging pooler URL and contains no password. `TARGET VERIFIED` (8 versions, 7 candidates, legacy world canon). |
| 4. Phase A | The dry run listed exactly the 8 historical versions, in order. The operator confirmed. All 8 were applied once each; `Finished supabase db push.`; no seeding. |
| 5. Checkpoint | `CHECKPOINT PASSED`: 16 versions, 1 stay node, no frontiers or spots. |
| 6. Phase B | The dry run listed exactly `202610020001`, `202610020002`. The operator confirmed. Both were applied once; no seeding. |
| 7. Validation | `POST-DEPLOY VALIDATION PASSED`: 18 versions, 7/7 candidates unchanged with the same `OUTLAND_WORK` world, 1 base with exact audit, RLS deny-by-default. `verify-sideworld-bases.sql` PASS. `verify-schema.sql` PASS (`legacy_compatible`; RIVERKEEPER `3fa8b58a…` resolved by profile). |
| 9. Cleanup | The deployment worktree was removed. |

**Final staging migration ledger:** 18 versions, all applied on staging, with 0 local-only and 0 remote-only:
`202608180001, 202608180002, 202608180003, 202608180004, 202608200001, 202608210001, 202609020001, 202609030001, 20260912141712, 20260912141742, 20260912145301, 20260913141314, 20260913141954, 20260917110721, 202609190001, 20260919100334, 202610020001, 202610020002`.

**Not run (no separate authorization):** the write-path suites `verify-workflow-security.sql` and `diagnose-compass-promotion.sql`. No `seed.sql` was run and no world record was changed.

**Evidence custody:**
- The full evidence is held outside Git with an owner-only ACL and a SHA-256 manifest. It covers the transcript, the dry runs and pushes, the before/after migration lists, the validation outputs and the summary, plus copies of the operator wrapper that was run.
- The backup is kept outside Git. A scan found no credentials in the transcript. No backup data is committed here.

**Earlier attempt, 00:12 the same day (stopped safely, no staging changes):**
- The local operator wrapper, which drives the runbook's steps, refused a correct Phase A dry run.
- **Why the drill missed it:** the Supabase CLI adds a JSON summary only when it detects AI-agent environment variables. The drill had run with them set, so a real console took the untested human-readable path.
- **Why it failed:** Windows PowerShell decoded the CLI's UTF-8 bullet (`•`) with code page 437, turning it into `ΓÇó`, so the list parser matched nothing.
- **Fix:** the wrapper now decodes UTF-8 and parses both output modes strictly (header, exact order, no unlisted filenames, text and JSON must agree). Its no-seed check no longer depends on the JSON line.
- The fix was drilled in text and JSON modes on the restored snapshot before the successful run.
- The approved migrations and the committed scripts were not changed.
