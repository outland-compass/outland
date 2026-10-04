# SIDEWORLD — staging go/no-go checklist (2026-10-03)

> **Current status (2026-10-04): Phase 1B CLOSED — deployed and validated on staging and production** (see the last two sections). The sections below are kept as the chronological decision record; their HOLD, "pending" and "production unmigrated" statements are superseded.

## Verified read-only inventory

- Staging Supabase project: `clgpxvyflycudzhdzjlv` (`outland-staging`), ACTIVE_HEALTHY.
- Exactly 8 recorded migrations, ending at `202609030001`. Production previously recorded 16; refresh both lists immediately before deployment.
- Staging has 8 `shared.worlds`, 7 `land.candidates` (all attached to `OUTLAND_WORK`), 0 `land.signals`, 0 `land.evaluations`, and 0 `shared.assets`.
- Staging world codes include `RIVERKEEPER`, `NAVIGATOR`, `ALIKI`; these are legacy records. Do NOT silently rename or delete them as part of this migration.
- Staging has no `universe.nodes`, `universe.frontiers`, `universe.spots`, `passport.journeys` or `infrastructure.bases` before catch-up.
- GitHub Database CI run 37123798090 passed clean migration replay, seeded existing-data upgrade, and staging-history rehearsal. The rehearsal uses synthetic data, NOT a snapshot of staging.

## Immutable data gate

Before migration, export full staging database with roles/schema/data and store it outside the runner; separately record counts and identifiers for all seven existing candidates and their world relationships. Confirm a restore can be completed into a disposable database. A green GitHub workflow is NOT a backup. If no recoverable snapshot or restore test is available: NO-GO.

## Rehearsal on actual snapshot

1. Restore staging snapshot into an isolated temporary database. Confirm baseline schema version 8 and seven candidates under `OUTLAND_WORK`.
2. Apply historical migration versions, in order:
   - `20260912141712` wanderer_mobile_radar
   - `20260912141742` wanderer_benchmark_image
   - `20260912145301` wanderer_decision_layer
   - `20260913141314` universe_v0_core_and_passport_journey
   - `20260913141954` greenhill_universe_node_v0
   - `20260917110721` pod_radar
   - `202609190001` discovery_signal_promotion
   - `20260919100334` add_poseljani_pod_radar_signal
3. Inspect resulting `universe.nodes` and `universe.frontiers/spots`; abort if unexpected node types or nonempty dependent tables appear.
4. Apply `202610020001_sideworld_bases_foundation` and `202610020002_sideworld_bases_legacy_backfill`.
5. Assert all seven candidate IDs, world IDs, related source records and business data are unchanged. Verify audit mapping, GREENHILL base parity, RLS deny-by-default, migration history and application smoke tests.
6. Document recovery time and capture verification evidence. Only then request separate founder authorization for real staging deployment.

## Remote staging execution gate

- No remote DDL/data writes or automated staging deployment until founder approval after successful real-snapshot rehearsal.
- Do not merge PR #29 solely because synthetic CI passed.
- Do not change production. Production migration requires separate approval and backup/rollback plan.

## Follow-up hardening

Clean-install SIDEWORLD post-seed parity remains distinct from upgrade validation. Decide whether to change the seed fixture or add an explicit, idempotent post-seed reconciliation path; do not weaken the upgrade assertions.

## Real staging-snapshot rehearsal — founder-provided Claude Code report (2026-10-03)

**Evidence provenance:** The following is transcribed from the founder's Claude Code terminal report. It has NOT been independently verified by this GitHub update: the backup and local rehearsal logs are on the founder's machine, outside this repository. No backup files, inventory rows, secrets, or credentials are committed here.

### Backup and isolated restore

- Local backup directory reported: `C:\Users\ThinkPad\outland-backups\staging-20261003-222200` (outside Git).
- Backup script reported completion and `inventory ok: True`. Files shown included `roles.sql`, `schema.sql`, `data.sql`, `staging-full.dump`, inventory CSVs and `SHA256SUMS.txt`.
- Claude subsequently reported that the original backup passed all 28 integrity checks and that a full restore into the disposable local environment took approximately 40 seconds. This is **not** a measured recovery time for the hosted Supabase staging project.
- The disposable environment was reported stopped after the rehearsal; the original backup was retained locally.

### Migration and data evidence

- Baseline: eight recorded staging migrations. Planned catch-up: eight historical versions listed above **plus two SIDEWORLD versions**, for ten pending versions in total.
- Claude's report states that `infrastructure.bases` contained one `GREENHILL N·01` row with matching source-node fields and timestamps; `infrastructure.base_legacy_migration_audit` contained one row with an exact source snapshot and no orphans. These observations support execution of both SIDEWORLD migrations in the local rehearsal.
- Claude reported all seven existing candidates and their world links intact after the historical migration rehearsal. Obtain and attach a sanitized version-by-version migration ledger and pre/post inventory comparison before treating the full ten-version rehearsal as independently auditable; the supplied excerpt does not include the full ledger.
- RLS was reported enabled on both new tables, with no policies; `anon`, `authenticated`, and `service_role` had no access to the new private schema/tables. Legacy Universe and Passport tables remained in place. Application access to bases is therefore **not** enabled by this phase.

### Reported SQL verification results

| Test | Result on restored staging snapshot |
| --- | --- |
| `verify-sideworld-bases` (PR branch) | PASS |
| `diagnose-compass-promotion` (PR branch) | PASS |
| `verify-workflow-security` (main) | PASS |
| `verify-workflow-security` (PR branch) | FAIL: required test worlds missing |
| `verify-schema` | FAIL: RAFTER floating Compass world missing |

Claude reported that scratch copies of the two failing tests pass when the RAFTER-specific assumptions are changed or removed. **The original test files were not modified.** This is evidence of a fixture/canonical-data mismatch, not a passing original suite; do not mark these checks green.

### Canonical-data discrepancy and deployment constraints

- The staging snapshot retains legacy world codes including `RIVERKEEPER` and `ALIKI`; the newer seed uses `RAFTER` and `ORIGIN`. Claude reported that the corresponding existing staging world records should preserve their UUIDs, and that blindly running the full seed could insert duplicate canonical worlds and modify unrelated existing rows. No full seed was run in the rehearsal.
- Resolve canonical naming as a **separate reviewed migration** or make staging-aware verification assertions without weakening clean-install checks. Do not rename world codes or alter existing world rows in this Phase 1B deployment.
- Backup connection was reported to use encrypted transport (`sslmode=require`) without certificate verification; improve this separately where supported.
- Concurrent application traffic and hosted-staging restore time were **not** tested. Recheck all live counts and migration versions immediately before any remote operation.
- The repository's local Supabase CLI linkage reportedly points to **production**. Any future authorized staging deployment must explicitly target the verified staging database; never rely on `--linked`. Do not put database credentials in shell history or CI logs.
- Migration versions must be ordered lexicographically as repository migration filenames, not converted to numbers.
- The backfill's retry/partial-failure behavior has not been independently validated; require a controlled transaction/failure and rollback review before deployment.

### Current gate and required evidence

**LOCAL REHEARSAL: conditional GO for the additive migration path; REMOTE STAGING: HOLD pending explicit founder authorization and closing evidence gaps.** This is not approval to deploy. Before staging: (1) archive a sanitized ten-version migration ledger and pre/post comparison; (2) explicitly disposition the two failing RAFTER-dependent tests without running the full seed; (3) review backfill failure/retry and hosted rollback procedure; (4) confirm the preserved local backup is accessible; (5) obtain founder approval for the exact staging-only execution plan. PR #29 remains Draft; production remains untouched.

## Closing evidence — Phase 1B pre-deployment verification (2026-10-03, second pass)

Full sanitized evidence: [`SIDEWORLD_STAGING_REHEARSAL_EVIDENCE.md`](SIDEWORLD_STAGING_REHEARSAL_EVIDENCE.md). The migration and test files are byte-identical at `0ec4221` and at the current head, because `1532075` is docs-only. Status of the evidence gaps listed above:

1. **Ten-version ledger and pre/post comparison: CLOSED.**
   - Versions were applied one at a time on a fresh restore. Each has its file SHA-256, git blob, exit code, timing, and recorded statement count with md5.
   - All 7 candidate IDs are shown hash-identical across staging, the restore and the post-migration state (excluding the added `development_model` column). All keep the same `world_id` (`OUTLAND_WORK`).
2. **RAFTER-dependent tests: DOCUMENTED, still FAIL, not marked green.**
   - The cause is the seed-only RAFTER/ORIGIN canon against staging's legacy RIVERKEEPER/ALIKI records.
   - No seed was run and no world record was modified.
   - A founder disposition is required; the options are in the evidence file, section 5.
3. **Backfill failure/retry and rollback: CLOSED (local).**
   - The CLI applies each migration atomically. A failed backfill leaves no partial objects but leaves the foundation committed.
   - Retry after fixing the cause succeeds.
   - The SIDEWORLD rollback SQL was verified from both the full and the partial state. It is exact (schema identical to the 8-migration state), and its guard aborts safely.
   - Historical migrations roll back only by backup restore. Restoring the hosted project was not rehearsed.
4. **Preserved backup: CONFIRMED.** Integrity checks passed 28/28 after the final teardown. The backup is stored outside Git and nothing from it is committed.
5. **Founder approval for the exact staging-only plan: OPEN.**

**Gate:** the migration path is technically GO. Remote staging remains on HOLD until items 2 (disposition) and 5 (approval) are signed off. This is not deployment approval, and production remains untouched.

## Test compatibility and deployment runbook (2026-10-03, third pass)

- **RAFTER test disposition: RESOLVED by option (b) in `119432c`.**
  - Clean installs keep strict RAFTER assertions (default `canonical` mode).
  - Upgraded legacy-canon databases opt in to `legacy_compatible`, which resolves the single River/GUARDIAN/FLOW floating world by profile, with no hardcoded ID.
  - Duplicate floating identities are rejected.
  - No security assertion was weakened, and no world record was changed.
- **Full Database CI, run `37155548122`: 4/4 jobs green.** That includes the clean-install canonical replay and the new `legacy-world-canon-upgrade` job, which seeds with the pre-#27 seed, runs every suite in `legacy_compatible` mode, and proves canonical mode still rejects the legacy canon.
- **Restored staging snapshot:** all 4 suites PASS in `legacy_compatible` mode (RIVERKEEPER resolved by profile). Canonical mode fails as intended. The 7 candidates and all world records are unchanged.
- **Staging-only runbook:** [`SIDEWORLD_STAGING_DEPLOYMENT_RUNBOOK.md`](SIDEWORLD_STAGING_DEPLOYMENT_RUNBOOK.md), with guarded scripts in `scripts/staging/`. Steps 3–8, including rollback and re-apply, were drilled end-to-end on a fresh snapshot restore with the committed scripts.

**Gate:** technically **GO**, and ready to deploy to staging. Remote execution remains on **HOLD** until written founder approval names the exact PR #29 SHA. A fresh backup (runbook step 2) is mandatory immediately before deployment. Production is untouched.

## Staging deployment: EXECUTED (2026-10-04)

- **Status:** Phase 1B was deployed to `outland-staging` from the approved SHA `63b0012839baa71c3922debaa4c3970b131333dd` and validated. All mandatory gates passed.
- **Ledger:** 18 versions.
- **Data:** the 7 candidates are unchanged and still linked to `OUTLAND_WORK`. No world record was renamed or changed outside the approved migrations; `20260912141712_wanderer_mobile_radar` intentionally updated the existing `WANDERER` world row (`radar_enabled`, `target_capital_min_eur`, `target_capital_max_eur`, `reunderwrite_above_eur`, `target_profile`, `search_notes`, `updated_at`), exactly as rehearsed on the restored snapshot.
- **Bases and access:** 1 base with exact audit provenance; RLS deny-by-default.
- **Backups:** a pre-deployment backup was taken and verified (`staging-full.dump` SHA-256 `0adc2c23…1310`, stored outside Git).
- **Full record:** [`SIDEWORLD_STAGING_REHEARSAL_EVIDENCE.md`](SIDEWORLD_STAGING_REHEARSAL_EVIDENCE.md), section 8.
- **Untouched:** production; PR #29 remains unmerged.

**Outstanding, outside this deployment:**
- Production rollout needs separate approval, a backup and a plan. Production already records the historical versions; the two SIDEWORLD versions are new there.
- Deployment protection: the normal checkout's CLI link to production was removed on 2026-10-04 and verified (no `supabase/.temp/project-ref` in any local worktree).
- Reconciling the staging world codes (RIVERKEEPER/ALIKI) is a separate decision.
- The optional write-path suites were not run on staging.
- A hosted restore has never been rehearsed.
- `infrastructure.*` grants nothing to `service_role`, so app access requires a future migration.

## Production deployment: EXECUTED (2026-10-04) — Phase 1B closed

- **Status:** Phase 1B was deployed to production (`huzcukdovavejejwohey`) and validated, 14:26:39–14:32:17 (+02:00). It was run from the PR #29 merge commit `0e91c7eb977c63b27ee570d9760bc939fd5ea7bf`, after separate founder approval, with a read-only Prepare run first. All gates passed. Applied: exactly `202610020001` and `202610020002`, once each, with no seed.
- **Ledger:** 18 versions. All are recorded on production, with 0 local-only and 0 remote-only.
- **Data:** per-row fingerprints of worlds, candidates, Universe nodes, frontiers and spots, and Passport journeys and events are byte-identical before and after (7/7).
- **Bases and access:** one base per legacy stay node, with an exact audit snapshot and no orphans. RLS is on, and `anon`, `authenticated` and `service_role` have no access to `infrastructure.*`. `verify-sideworld-bases` passed.
- **Backup:** pre-deployment `staging-full.dump` SHA-256 `e7e900c58a8d2c78b9008f9d8d77e9f8f05ef2e58b66ab57e0f619015b0942c1`. It was verified and is stored outside Git.
- **Founder smoke test:** passed after deployment.
- **Full record:** [`SIDEWORLD_STAGING_REHEARSAL_EVIDENCE.md`](SIDEWORLD_STAGING_REHEARSAL_EVIDENCE.md), section 9.

**Remaining, outside Phase 1B:**
- Application or `service_role` grants for `infrastructure.*`, which require a future migration.
- Reconciling staging's legacy world codes (RIVERKEEPER/ALIKI).
- Restoring into a hosted project has never been rehearsed.
- The optional write-path suites were not run on staging or production.
