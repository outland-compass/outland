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
