# SIDEWORLD Studio — transactional universe writes (implementation contract)

Status: **design / not deployed**. The current Studio write endpoint returns HTTP 503.
Do not enable it merely because CI passes.

## Canonical scope
Only `universe.universes` defines universes. Never create a second universe table.

- Direct: `universe.worlds.universe_id`, `universe.themes.universe_id`, `canon.franchises.universe_id`.
- Indirect: `canon.series.franchise_id`, `canon.characters.franchise_id`,
  `canon.factions.franchise_id`, `canon.lore_facts.franchise_id`,
  `canon.canon_rules.franchise_id`.
- Optional relationships (series/theme, lore/series, rule/series/character) must match the same universe and parent franchise.
- `geo.cities`, countries, locations, facts, and sources are **shared geographic truth**, not owned by a universe.
  Do not attach a city to a universe simply to authorize edits.
- `universe.world_cities` links a world to a shared city; authorize via the world.

## Required write contract
1. Authenticate user and authorize global OWNER/ADMIN (V1 policy). No per-universe ACL is claimed.
2. Client supplies an active universe slug, entity and validated payload.
3. A single PostgreSQL SECURITY DEFINER guarded-write RPC resolves slug, validates all parent IDs,
   verifies the existing record (if updating) already belongs to that universe, and mutates in
   the **same transaction**. Never trust a client-supplied universe ID.
4. Reject attempts to reparent an existing entity into another universe. Cross-universe moves
   require a separate explicit, audited administrative workflow.
5. Reject foreign series/theme/character references, including nullable relationships when present.
6. Avoid exposing generic service-role write RPCs through the app once guarded RPCs are active.
   Review EXECUTE grants, search_path, error handling and logging.
7. Shared geo edits need a separate global-content authorization policy and explicit UI context;
   do not pretend they are universe-scoped.
8. Deny unknown entities and missing universe; fail closed on RPC/config errors.

## Rollout
- Inspect all existing RPC definitions, migrations, RLS/grants and consumers before replacing anything.
- Add guarded RPCs in new migrations; retain existing RPCs until callers are migrated.
- Test same-universe insert/update, wrong-universe existing-ID update, mismatched optional FKs,
  missing/deleted parents, shared-geo policy, role failures and rollback.
- Replay migrations in CI and test staging with separate identities for two universes.
- Confirm backup availability and restore readiness before any production DB migration.
- Only then remove HTTP 503 gate and re-enable editor UI behind a feature flag.
- No production migration or deployment without explicit authorization.

## Rollback
Disable write feature flag / reinstate HTTP 503, then revert app deployment. Prefer leaving additive
guarded RPCs in place until dependencies are removed; drop only after verifying no callers remain.
