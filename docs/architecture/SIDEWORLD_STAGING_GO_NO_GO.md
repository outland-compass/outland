# SIDEWORLD — staging go/no-go checklist (2026-10-03)

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
