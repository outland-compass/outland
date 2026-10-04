# Legacy Universe V0 cleanup — prepared, not deployed

## Scope and authority

On 2026-10-04 the founder authorized bounded cleanup preparation and testing before SIDEWORLD development. Production removal requires separate approval of the reviewed commit. PR #29 and #30 are already merged; this is a new change. No World registry redesign, app grants, quests or staging World renaming is included.

The migration removes `universe.nodes`, `universe.frontiers`, `universe.spots` and the unused Passport columns `journeys.node_id`, `events.node_id`, `events.frontier_id`, `events.spot_id`. It preserves Passport tables/rows, shared/land records, Bases and audit snapshots. Columns must contain no values. Unknown database dependencies cause RESTRICT to stop the transaction; CASCADE is never used.

The `universe` schema and `universe.set_updated_at` function remain because `passport_journeys_set_updated_at` still uses the function. This is a timestamp helper, not a second Universe registry. Moving that helper is outside this bounded cleanup.

## Read-only audit (2026-10-04)

Production `huzcukdovavejejwohey` and staging `clgpxvyflycudzhdzjlv` each contain one stay node, zero frontiers/spots, zero journeys/events. Every source field matches the Base and audit snapshot. Four Passport FKs and two internal legacy FKs exist. No table-name references were found in inspected database function bodies, views or policies. The repository application scan found no queries against the legacy tables. The production Edge Function `import-listing` uses Auth and imports listings without querying these tables; staging has no Edge Functions. External consumers outside these inspected systems cannot be conclusively ruled out by a catalog/code scan.

Historical migrations remain byte-identical. Historical Phase 1B checkpoint/deployment scripts remain execution evidence and must not be reused after cleanup. Current verification and seed use Bases instead. Historical upgrade CI uses the exact pre-cleanup seed from `05105f7`; the legacy World scenario retains its existing pre-#27 seed.

## Deployment gates

1. Review the exact PR commit and require all Database CI jobs to pass. Keep the PR draft until reviewed. No app source changes are required, but PR previews can still deploy automatically.
2. Before staging execution, take and verify a fresh backup and rehearse the new migration and recovery against its restored copy. Capture worlds/candidates, Bases/audit and Passport fingerprints. No hosted staging or production DDL has been executed by this preparation.
3. Pin an isolated, unlinked checkout to the reviewed SHA. Freeze edits for the short execution window. Use an explicit database URL; never `db push --linked`.
4. Verify target identity and migration history. Dry run must list exactly `20261004140102_retire_legacy_universe_v0.sql`; stop for any other version or unexpected target.
5. Execute the single migration only on the authorized target, without seed. It locks source/mapping/Passport tables, checks parity and unused references, and drops with RESTRICT. Lock timeout is five seconds. Set a sixty-second statement timeout on the deployment connection. All DDL and guards are one atomic DO statement, including when the CLI executes migration statements independently.
6. Run `verify-sideworld-bases.sql` and `verify-schema.sql` (staging uses `outland.world_canon=legacy_compatible`). Require 19 ledger versions, no legacy tables/reference columns, preserved Base/audit/Passport fingerprints and unchanged shared/land fingerprints. Test the existing COMPASS flows.
7. Archive evidence and restore results. Production requires a separate exact-commit approval, fresh verified production backup and successful restored-production rehearsal. A staging pass is not production authorization.

## Recovery

A migration error rolls back the entire transaction. Stop on the first failed gate; do not rerun blindly or roll back Phase 1B.

If cleanup committed and approved recovery is needed, use `scripts/legacy-cleanup/recover.sql` with `psql -X -1 -v ON_ERROR_STOP=1` on the explicitly verified target. It recreates the three original tables, restores exact nodes from audit snapshots and recreates the four empty Passport columns, FKs and indexes. It preserves existing Passport/Base/audit rows and rejects pre-existing legacy tables. Compare restored rows with the verified pre-cleanup backup and verify RLS/FKs. A full verified backup remains necessary if audit records have been lost or changed.

Only after successful recovery and its checks, reconcile the cleanup migration ledger using the CLI's documented `migration repair` command for this exact version. Do not delete history rows by hand. Recovery is operator tooling, not an automatically applied migration.

## Validation status

Local isolated PostgreSQL drills passed normal cleanup/recovery, missing audit, modified Base, modified snapshot, unexpected frontier, Passport reference, unknown dependent view, and preservation of Passport rows without legacy references. Full local schema/seed replay checks use a lightweight Auth/Storage bootstrap in the isolated runtime; these are supplementary and do not replace real Supabase CI. Live staging execution, restored hosted snapshot rehearsals and production execution remain pending.

The first real CI run caught an outer LOCK TABLE outside a transaction. The migration now uses one atomic DO statement; isolated drills must also run it without an outer transaction. No live DDL was performed.
