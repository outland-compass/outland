# SIDEWORLD V3.1 — Additive Migration Plan

**Status:** design/review plan only  
**Production execution:** NOT AUTHORIZED  
**Baseline:** live production reconciled read-only on 2026-10-05

## 1. Objective

Introduce the minimum durable SIDEWORLD V3.1 data foundations without changing or replacing existing OUTLAND operational models.

The plan is intentionally additive:
- preserve `shared.worlds` and all existing UUIDs;
- preserve `shared.assets`;
- preserve deployed `infrastructure.bases`;
- preserve legacy `universe.nodes/frontiers/spots`;
- preserve `passport.journeys/events`;
- preserve all LAND/COMPASS reads/writes.

No migration in this plan drops, renames or rewires existing production objects.

## 2. Schema placement decision for review

Because the live database already has the `universe` schema, V3.1 proposes coexistence rather than a schema rename:

Existing legacy V0:
- `universe.nodes`
- `universe.frontiers`
- `universe.spots`

New canonical SIDEWORLD:
- `universe.universes`
- `universe.franchises`
- `universe.stories`
- `universe.characters`
- `universe.factions`
- `universe.lore_entries`
- `universe.worlds`
- relation tables

This is acceptable only if replay, RLS and generated-type validation show no ambiguity or exposure regression. If not, STOP before implementation and return for founder approval on schema naming.

## 3. Proposed migration sequence

Use real timestamp prefixes at implementation time; do not reuse historical timestamps.

### Migration A — `*_sideworld_universe_story_foundation.sql`

Create additive canonical narrative tables in `universe`:

#### `universe.universes`
- `id uuid primary key default gen_random_uuid()`
- `slug text unique not null`
- `name text not null`
- `description text null`
- `visibility text not null default 'private'`
- `status text not null default 'draft'`
- `metadata jsonb not null default '{}'`
- timestamps

Checks:
- nonblank slug/name;
- controlled visibility/status values.

#### `universe.franchises`
- `id`
- `universe_id → universe.universes(id) on delete restrict`
- slug/name/description/status/metadata/timestamps
- unique `(universe_id, slug)`

#### `universe.stories`
- `id`
- `franchise_id → universe.franchises(id)`
- `parent_story_id → universe.stories(id) null`
- `story_type text`
- slug/title/synopsis/sequence/spoiler_level/status/metadata/timestamps
- unique `(franchise_id, slug)`

Initial allowed story types:
- `arc`
- `story`
- `chapter`
- `episode`

Prevent direct self-parenting with a check; deeper cycle validation can be application-level initially.

#### `universe.characters`
Canonical character identity:
- `id`
- `universe_id`
- slug/canonical_name/summary/status
- `character_pack jsonb`
- metadata/timestamps
- unique `(universe_id, slug)`

#### `universe.factions`
- `id`
- `universe_id`
- slug/name/description/ideology/status/metadata/timestamps
- unique `(universe_id, slug)`

#### `universe.lore_entries`
- `id`
- `universe_id`
- `franchise_id null`
- `story_id null`
- slug/title/body/spoiler_level/status/metadata/timestamps

Scope rule should be validated so any franchise/story belongs to the same universe.

#### Junctions
- `universe.franchise_characters(franchise_id, character_id, role, ...)`
- `universe.story_characters(story_id, character_id, role, ...)`
- `universe.franchise_factions(franchise_id, faction_id, role, ...)`
- `universe.story_factions(story_id, faction_id, role, ...)`
- `universe.story_lore(story_id, lore_entry_id, reveal_role, ...)`

All new tables:
- RLS enabled;
- no anon/authenticated/service_role grants in the foundation migration unless separately approved;
- indexes on all FKs.

### Migration B — `*_sideworld_universe_worlds_foundation.sql`

Create `universe.worlds` as the SIDEWORLD experience/content/demand registry.

Fields:
- `id uuid primary key`
- `universe_id → universe.universes(id)`
- `slug`
- `name`
- `description`
- `world_type text null`
- `status text default 'draft'`
- `metadata jsonb`
- timestamps
- unique `(universe_id, slug)`

Important invariant:
`universe.worlds.id` is NOT `shared.worlds.id` by definition.

Create `universe.world_operational_links`:
- `universe_world_id → universe.worlds(id)`
- `operational_world_id → shared.worlds(id)`
- `relationship_type`
- `status`
- `source_signal_id uuid null` initially without FK unless signal ownership is approved
- metadata/timestamps
- composite PK or unique pair

No automatic insert into `shared.worlds`.

### Migration C — `*_sideworld_geography_foundation.sql`

Create schema `geography`.

#### `geography.cities`
- `id uuid primary key`
- slug/name/country_code/region/timezone
- center latitude/longitude
- status/metadata/timestamps
- suitable uniqueness strategy based on country + slug

#### `geography.locations`
- `id uuid primary key`
- `city_id → geography.cities(id)`
- slug/name/location_type
- latitude/longitude
- address/access_notes/opening_hours
- `physical_features jsonb`
- `verification_status`
- `last_verified_at`
- `source_evidence jsonb`
- metadata/timestamps

Create `universe.world_cities`:
- `world_id → universe.worlds(id)`
- `city_id → geography.cities(id)`
- role/status/metadata
- unique `(world_id, city_id)`

Do not migrate `universe.spots` into `geography.locations` automatically.

### Migration D — `*_sideworld_signal_quest_foundation.sql`

Create schema `signal`.

#### `signal.quests`
- `id`
- `city_id → geography.cities(id)`
- `world_id → universe.worlds(id) null`
- slug/title/description/status
- duration/distance/difficulty/audience
- metadata/timestamps

#### `signal.quest_stories`
- `quest_id`
- `story_id → universe.stories(id)`
- `role text default 'primary'`
- unique pair

Possible roles:
- primary
- secondary
- reveal

#### `signal.quest_versions`
- `id`
- `quest_id`
- `version_number integer`
- status
- generator/canon metadata
- published_at
- created_at
- unique `(quest_id, version_number)`

Published versions are immutable by application policy; consider DB trigger enforcement only after workflow is proven.

#### `signal.stops`
- `id`
- `quest_version_id`
- `location_id → geography.locations(id)`
- sequence
- arrival/completion copy
- safety/fallback metadata
- unique `(quest_version_id, sequence)`

#### `signal.puzzles`
- `id`
- `stop_id`
- type/prompt/answer
- accepted answers / hints / fallback
- difficulty
- validation evidence
- metadata

All tables private/RLS-on initially.

### Migration E — `*_sideworld_world_metrics_foundation.sql` — DEFERRED BY DEFAULT

Do not create until product instrumentation produces real demand data.

If/when justified, create `universe.world_metrics` for period aggregates and provenance.

No trigger from metrics to `shared.worlds`.

## 4. Seed strategy

Foundation migrations should not silently create broad demo content.

Potential first canonical rows (OUTLAND universe, first franchise, etc.) should be added only through:
- a reviewed seed file for local/staging; or
- a separate explicit data migration if production canon must be initialized.

Do not mix schema foundation with large AI-generated content.

## 5. API exposure strategy

Initial safest state:
- new `universe` V3.1 tables remain private despite sharing a schema with legacy private V0;
- new `geography` and `signal` schemas remain private;
- no direct browser writes.

Later, expose only the minimum read/write surfaces required by the SIDEWORLD app through separately reviewed grants/RLS or RPC/API boundaries.

Do not change current `supabase/config.toml` exposed schemas in the foundation PR unless the first application slice requires it.

## 6. Generated types / application impact

After each accepted migration set:
1. regenerate Supabase TypeScript types;
2. verify no changes break COMPASS generated type consumers;
3. do not modify CompassRepository to use `universe.worlds`;
4. preserve its `shared.worlds` behavior;
5. add new SIDEWORLD repositories/services separately.

## 7. Verification requirements

### Clean replay
- `supabase db reset` on isolated/local DB;
- all migrations apply from zero;
- existing schema tests still pass;
- new V3.1 verification SQL passes.

### Upgrade rehearsal
Restore a current production/staging snapshot into isolation, then apply the new migrations.

Assert byte/data parity for existing:
- `shared.worlds`
- LAND candidates/evaluations/signals
- `shared.assets`
- `infrastructure.bases`
- legacy `universe.nodes/frontiers/spots`
- `passport.journeys/events`

### RLS negative tests
Confirm anon/authenticated cannot access new private schemas/tables unless explicitly granted.

### Application regression
- Compass build/test;
- OUTLAND World build/test;
- existing production smoke paths;
- no change to current `shared.worlds` queries.

## 8. Rollback design

Before any application writes:
- rollback may drop only the newly created V3.1 tables/schemas;
- guard rollback with zero-row / dependency checks;
- never use CASCADE as a shortcut.

After application writes:
- prefer forward-fix migrations;
- preserve a pre-deployment verified backup;
- rollback scripts must identify and protect new content before removing structure.

Existing OUTLAND tables are never part of V3.1 rollback deletion.

## 9. Demand-to-operations bridge

The bridge table may be created in Migration B because it is structurally harmless, but automated promotion is explicitly out of scope.

Before implementing expansion signals, decide:
1. dedicated SIDEWORLD `universe.expansion_signals` vs existing `land.signals`;
2. metric provenance/confidence;
3. approval states;
4. idempotency;
5. creation workflow for a new `shared.worlds` record;
6. how the new operational World enters COMPASS scoring/search.

No automatic trigger or Edge Function may create an operational World without founder-approved workflow.

## 10. Proposed PR sequence

Prefer small reviewable PRs:

1. **V3.1 docs only** — architecture + migration plan. No migrations.
2. **Universe narrative foundation** — Migration A + tests/types.
3. **Universe Worlds + geography** — Migrations B/C + tests/types.
4. **Quest foundation** — Migration D + tests/types.
5. **First playable quest slice** — minimal app access/RLS + Valletta/Novi Sad content as separately approved.
6. **Metrics/expansion** — only after real usage evidence.

Each implementation PR requires a fresh read-only production/deployment check before merge/deploy.

## 11. Explicit non-goals

This plan does NOT:
- change production now;
- rename `shared.worlds`;
- migrate OUTLAND Worlds into SIDEWORLD Worlds;
- create duplicate copies of existing Worlds;
- delete legacy V0;
- expose new schemas to browsers;
- create a generalized AI engine;
- authorize automated investment actions.
