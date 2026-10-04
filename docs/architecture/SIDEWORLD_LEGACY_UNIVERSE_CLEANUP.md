# SIDEWORLD legacy Universe cleanup — execution gate

Status: approved direction; NOT deployed. Do not run destructive DDL before the gates below pass.

## Canonical ownership
- `shared.worlds` is the sole World registry; retain existing UUIDs and Compass fields.
- `core.universes` is the planned sole Universe registry; `core.universe_worlds` joins it to `shared.worlds`.
- `infrastructure.bases` is the sole new accommodation table; no replacement `nodes` table.
- `shared.assets` remains the physical-asset source of truth.
- `geography.locations` stores physical POIs; `signal.stops` uses locations in quests; `signal.artifacts` stores gameplay collectibles.
- Legacy `universe.nodes/frontiers/spots` are frozen for new SIDEWORLD development, but remain physically present until compatibility is verified.

## Verified read-only production snapshot (2026-10-02)
- `shared.worlds`: 8 rows; `universe.nodes`: 1; `universe.frontiers`: 0; `universe.spots`: 0; `passport.journeys`: 0; `passport.events`: 0.
- Sole node is GREENHILL N.01, `stay`, `planned`, asset_id NULL. Preserve its metadata and original UUID in a migration audit record; map it to one `infrastructure.bases` row when the base schema is approved.
- `passport.journeys.node_id` and `passport.events.node_id/frontier_id/spot_id` reference legacy tables. Existing `supabase/tests/verify-schema.sql` explicitly asserts legacy tables and GREENHILL node.
- The Compass Worlds screen reads and updates `shared.worlds`; do not refactor Compass in this cleanup.
- No direct legacy table references were found in checked views or selected functions, but full application and external-client dependency proof is outstanding.

## Ordered gates
1. Confirm PR #27 migration reconciliation, clean local reset, and current production/staging migration parity. Inventory all repo and deployed application queries, API consumers, functions, views, policies and grants before deletion.
2. Add `core.universes` / `core.universe_worlds` and, when required, `infrastructure.bases` in separate additive migrations. Never create `core.worlds` or `infrastructure.assets`.
3. Backfill GREENHILL N.01 into `infrastructure.bases` with an explicit one-to-one migration mapping and preserved metadata. Validate world_id and source UUID mapping.
4. Adapt Passport foreign keys and consumers without losing historical semantics. Keep legacy tables while old consumers may still exist.
5. Replace legacy-specific checks in `supabase/tests/verify-schema.sql` with checks for canonical models, data parity and RLS; retain Compass regression assertions.
6. Replay migrations on isolated staging; run RLS negative tests, both application builds, and end-to-end quest tests. Capture rollback plan and data backup.
7. Only after a separate explicit production deletion approval, create a separate cleanup migration for old Passport columns/FKs, legacy tables, triggers and indexes. Do not use CASCADE as a substitute for dependency audit.

## Stop conditions
Any unexpected nonzero legacy usage, unidentified external consumer, failed local reset/build/RLS check, or missing migration audit mapping blocks deletion. No production changes are authorized by this document.
