# SIDEWORLD Architecture & Data Model V3.1

**Status:** approved conceptual direction; implementation not authorized by this document  
**Baseline refreshed:** 2026-10-05 (read-only GitHub + Supabase + Vercel reconciliation)

## 1. Core separation

SIDEWORLD and OUTLAND intentionally use two different World concepts.

### SIDEWORLD Universe World

`universe.worlds` represents an experience/content/demand context used by SIDEWORLD.

Examples:
- DIVING_MALTA
- HILTON_THAILAND
- a cross-city mystery region
- a franchise-specific experiential geography

A Universe World may span many cities and may exist forever without any OUTLAND property, base or investment.

### OUTLAND operational World

Existing `shared.worlds` represents an OUTLAND operational/investment World used by COMPASS/LAND, assets, Passport V0 and physical operations.

Examples include the existing GREENHILL, RAFTER and ORIGIN records.

These two registries are **not duplicates**. Their semantics, lifecycle and ownership are different. They may use distinct UUIDs.

## 2. Canonical hierarchy

```text
SIDEWORLD
└── UNIVERSE
    ├── FRANCHISE
    │   ├── STORY
    │   ├── CHARACTER
    │   ├── FACTION
    │   └── LORE
    │
    └── UNIVERSE WORLD
        ↕
       CITY
        └── LOCATION
```

Narrative and geography are parallel. Stories reference geography through adaptations such as quests, rather than owning cities or locations.

## 3. Approved narrative model

- `universe.universes` — one canonical SIDEWORLD Universe registry.
- `universe.franchises` — durable narrative properties inside a Universe.
- `universe.stories` — hierarchical story units using `parent_story_id` and a type such as `arc | story | chapter | episode`.
- `universe.characters` — canonical character identities.
- `universe.factions` — canonical organizations/groups.
- `universe.lore_entries` — structured canonical knowledge.
- junction tables connect franchises/stories to characters, factions and lore where M:N is required.
- `theme` remains a reusable treatment layer; it is not canonical story/character ownership.

## 4. Approved geography model

- `universe.worlds` — SIDEWORLD experience/content/demand Worlds.
- `geography.cities` — global city registry.
- `universe.world_cities` — M:N relation between Universe Worlds and cities.
- `geography.locations` — canonical physical POIs/places.
- quest stops reference `geography.locations`; locations are not duplicated per quest.

Do not reuse legacy `universe.spots` as the new global Location model. Legacy spots belong to OUTLAND Universe V0 semantics.

## 5. Quest bridge

Recommended quest domain:

```text
universe.stories
      ↕
signal.quest_stories
      ↕
signal.quests
      ↓
signal.quest_versions
      ↓
signal.stops ───→ geography.locations
      ↓
signal.puzzles
```

A quest is a playable adaptation connecting canonical story to real geography.

Published quest versions should be immutable.

## 6. OUTLAND physical/operational model retained

The following remain separate and are not replaced by SIDEWORLD narrative tables:

- `shared.worlds` — OUTLAND operational/investment Worlds.
- `shared.assets` — physical assets.
- `infrastructure.bases` — accommodation capacity.
- LAND/COMPASS candidate, scoring, evaluation and signal tables.

Existing `shared.worlds` UUIDs and dependencies must be preserved.

## 7. Universe World ↔ OUTLAND World bridge

Use an explicit M:N relation, working name:

`universe.world_operational_links`

Recommended fields:
- `universe_world_id`
- `operational_world_id` → `shared.worlds.id`
- `relationship_type`
- `status`
- `source_signal_id` nullable
- timestamps

Possible relationship types:
- `originated_from_demand`
- `supports_experience`
- `primary_capacity`
- `partner_capacity`
- `related`

The bridge must never imply that every Universe World requires an OUTLAND World.

## 8. Demand-to-capacity expansion loop

```text
SIDEWORLD content
      ↓
players / visits / intent
      ↓
Universe World metrics
      ↓
capacity-gap evaluation
      ↓
EXPANSION SIGNAL
      ↓
human review / approval
      ↓
new shared.worlds record only if justified
      ↓
COMPASS / LAND workflow
```

Metrics are evidence, not investment authorization.

No database trigger should automatically create a `shared.worlds` row because a threshold is crossed.

Recommended metrics entity (when product evidence justifies it):
`universe.world_metrics`

Possible fields:
- `world_id`
- `period_start`
- `period_end`
- `unique_players`
- `quest_starts`
- `quest_completions`
- `repeat_players`
- `accommodation_interest`
- `known_partner_capacity_nights`
- `estimated_demand_nights`
- `capacity_gap_nights`
- provenance / confidence metadata

## 9. Transmedia canon

The same canonical story source should feed multiple media:

```text
Canon + Story + Context + Player State
                 ↓
          SIDEWORLD Compiler
           /      |      \
          /       |       \
 QuestPackage VideoPackage GamePackage
```

Do not maintain independent quest-story, video-story and game-story truth.

Future Content OS entities may include:
- canon revision registry;
- canonical asset registry;
- generator definitions/versions;
- generation runs;
- evaluation runs.

Build these only when real generator workflows require them.

## 10. Verified production baseline

Read-only reconciliation on 2026-10-05 confirmed:

- canonical repo: `outland-compass/outland`, default branch `main`;
- production Supabase project: `outland`;
- relevant live schemas include `shared`, `land`, `universe`, `passport`, `infrastructure`;
- `core`, `signal` and `geography` were not present in the checked live catalog;
- `shared.worlds` has active cross-domain dependencies;
- `infrastructure.bases` is deployed;
- legacy `universe.nodes/frontiers/spots` and `passport.journeys/events` remain;
- Vercel production projects `outland` and `outland-world-v0` were READY on the checked current `main` commit.

Refresh this baseline immediately before any implementation.

## 11. Existing `universe` schema collision

The database already has a schema named `universe` containing legacy OUTLAND V0 tables.

V3.1 keeps that historical data intact.

Preferred additive direction:
- retain legacy `universe.nodes`, `universe.frontiers`, `universe.spots` unchanged;
- add new V3.1 canonical tables alongside them in the same `universe` schema only after replay/testing proves naming and permission safety;
- explicitly label V0 tables as legacy in docs/tests;
- do not drop/rename V0 tables as part of the V3.1 foundation.

If implementation review finds that coexistence creates unacceptable API/RLS/ownership risk, stop and return for founder approval before choosing a new schema name.

## 12. Implementation invariants

1. One canonical SIDEWORLD Universe registry.
2. `universe.worlds` and `shared.worlds` are distinct by design.
3. No automatic promotion from demand metric to operational World.
4. Preserve all existing OUTLAND operational UUIDs and dependencies.
5. Additive migrations only.
6. No historical migration rewrites.
7. Legacy V0 remains until separately approved cleanup.
8. New geography does not reuse legacy spots.
9. Published quest versions are immutable.
10. Production DDL/data writes require explicit founder approval.

## 13. Next implementation step

Prepare a non-executing migration plan for:
1. canonical Universe + Franchise + Story foundation;
2. Universe Worlds and World ↔ City relationship;
3. Geography City + Location foundation;
4. Quest foundation;
5. optional demand/operational bridge, initially without automated promotion.

No production migration is authorized by this architecture document.
