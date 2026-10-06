# SIDEWORLD Schema V3.2 — Canonical Architecture

**Status:** Founder-approved architecture direction  
**Date:** 2026-10-06  
**Scope:** SIDEWORLD canonical data ownership inside the shared Supabase project

## Canonical boundary

```text
universe.universes
= canonical SIDEWORLD Universe registry

universe.worlds
= canonical SIDEWORLD World registry

shared.worlds
= OUTLAND/COMPASS operational World registry
```

These concepts are intentionally distinct.

`shared.worlds` contains existing OUTLAND operational/investment configuration and has established dependencies across LAND, assets, Bases and legacy Passport V0. It must not be renamed, repurposed or promoted into the canonical SIDEWORLD narrative World registry.

SIDEWORLD canonical Worlds live in `universe.worlds`.

Where a SIDEWORLD World represents the same real OUTLAND operational World, the relationship is explicit:

```text
universe.world_outland_map
```

Do not infer identity from matching UUIDs or names.

## Approved domains

```text
universe
= SIDEWORLD Universe/World topology and reusable themes

geo
= real-world geography, facts, provenance and field-verifiable knowledge

canon
= fictional IP truth, characters, franchises, series, factions and continuity rules

signal
= playable quest/story delivery model

passport
= person/player-specific persistent experience state
```

Existing OUTLAND operational domains remain:

```text
shared
land
infrastructure
```

## OUTLAND boundary

Existing dependencies continue to reference:

```text
shared.worlds
```

including:

```text
land.*
shared.assets
infrastructure.bases
passport.journeys
passport.events
```

The SIDEWORLD foundation does not repoint them.

The OUTLAND domains also keep these roles:

- `infrastructure.bases` remains OUTLAND accommodation and capacity. No competing `places.base` is created.
- `land.*` remains OUTLAND/COMPASS.
- `shared.activities` remains the OUTLAND operational audit.

## `universe` schema reuse

The legacy Universe V0 tables have been retired.

The schema still contains:

```text
universe.set_updated_at()
```

because the existing `passport.journeys` trigger depends on it.

The helper is retained for compatibility while the schema gains the new canonical SIDEWORLD tables.

## Initial canonical SIDEWORLD tables

```text
universe.universes
universe.worlds
universe.themes
universe.world_cities
universe.world_outland_map

geo.countries
geo.cities
geo.locations
geo.location_facts
geo.sources
geo.fact_sources

canon.franchises
canon.series
canon.characters
canon.character_relationships
canon.factions
canon.lore_facts
canon.canon_rules
```

Signal and SIDEWORLD Passport additions follow after foundation validation.

## Security posture

Authoring schemas remain private by default.

Do not expose raw `universe`, `geo`, or `canon` tables to consumer Data API roles during the foundation migration. They are not added to the Compass Data API schemas (`supabase/config.toml` `api.schemas`). RLS is enabled and all privileges are revoked from `anon`, `authenticated` and `service_role`.

Studio/API access is a separate reviewed step.

Consumer runtime will eventually receive curated published contracts rather than unrestricted authoring-table access.

## Superseded direction

The earlier `core.universes` / possible `core.worlds` proposal is superseded.

The older OUTLAND-scoped statement that `shared.worlds` must remain the single World identity for every future SIDEWORLD concern is also superseded.

That statement remains understandable in historical OUTLAND OS documents, but it must not override this SIDEWORLD architecture.
