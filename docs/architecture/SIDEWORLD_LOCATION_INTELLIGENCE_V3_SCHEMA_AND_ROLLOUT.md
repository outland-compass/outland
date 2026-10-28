# SIDEWORLD Location Intelligence V3 — additive schema / rollout

**Status:** proposed in GitHub PR, not authorized for production execution. **Owner:** `outland-compass/outland` canonical Supabase migration history. **Scope:** one real-world GEO registry with private, reusable intelligence and canon overlays across franchises.

## Verified preflight (2026-10-28)

- Production project: `huzcukdovavejejwohey`. `geo.locations`: **61** Novi Sad places; `geo.location_facts` contains **54** V3 research dossiers with original V2 payloads; existing 11 franchise records in `canon.franchises`.
- Existing `geo.location_facts`/`geo.sources`/`geo.fact_sources` already provide assertion, source, and provenance graph. Existing `geo.location_media` already owns evidence photographs with rights controls.
- `canon.franchises`, `canon.series`, `canon.characters`, and `universe.universes` are **canonical**. No new universe/franchise registry.
- Studio reads `public.sideworld_studio_city_knowledge` (unchanged); the Player uses separate quest release snapshots (unchanged). `geo` and `canon` are outside Data API exposure; RLS enabled in current schema.
- This PR does not alter Player map pin logic, deploy an API, publish any quest, or override older source quality metadata.

## Three layers

### 1. GEO — real-world entity identity

- Keep `geo.locations` as the only canonical physical-place identity, preserving UUIDs and current numeric coordinate columns.
- `geo.location_hierarchy`: a **same-city**, **acyclic** containment relationship for place -> area object -> detail. The edge is absent until its geographical containment is supported; never infer that six objects sharing a park-coordinate pin are one physical object.
- `geo.location_research_candidates`: reusable intake, with nullable `location_id` and original source JSON; a research intake row is not a second canonical place. The 54 Novi Sad archival facts are **linked** to their already-existing `geo.locations` during migration.
- `geo.location_clues`: finer visible physical details, historical footprints, and safe reference/observation hints. These are not collectibles, accommodation `base`, or partner/business records. Nullable coordinates and uncertainty prevent invented waypoints.

### 2. Location Intelligence — source-backed claims

- Reuse **existing** `geo.location_facts`, `geo.sources`, `geo.fact_sources` and `geo.location_media` instead of duplicating facts or photographs. Add optional `source_locator`, `source_excerpt`, and `observed_at` to evidence edges.
- Retain `supports` / `contradicts` / `context`. All imported V2/V3 claims and franchise suggestions remain hypotheses until genuinely corroborated; the prior context-only citations are not automatically upgraded.
- Research dossiers are preserved with the unmodified original JSON payload and their original facts; decomposition into atomic claims is an **incremental AI research task**, not a risky data migration. Historical legends, disputed, missing or relocated artifacts stay explicitly distinguished from extant physical clue objects.

### 3. Canon — franchise-specific narrative/gameplay overlay

- `canon.location_franchise_fits`: **many-to-many** canonical `geo.locations × canon.franchises`, optionally scoped to canonical `canon.series`. A location may host different story angles for Beyond the Atlas, Chronicles, Partners in Crime, etc.
- `canon.location_character_uses`: canonical `canon.characters` linked only to same-franchise fits; database composite FKs enforce that invariant.
- `canon.location_clue_uses`: franchise-specific puzzle mechanics and narrative contexts applied to reusable real-world clue records.
- Existing V2 hypotheses are copied **only** with `status=hypothesis`; no lore or canon is secretly approved. Ambiguous franchise slugs are omitted from the backfill rather than linked to the wrong universe.

## Locked gameplay policy

All researched locations default to **navigation eligible**, without per-location approval queues, publication switches or field QA gates. Preserve reference precision and lawful public access metadata. The **only mandatory human field pass** is walking the *complete generated quest* before that quest is publicly released. This still requires source honesty and safe public route selection; missing artifacts are contextual, not physical entrances.

## Security boundary

All six new tables are RLS-enabled and denied to `public`, `anon`, `authenticated`, and direct `service_role` access. No new public RPC or Player authorization route is created. Trusted server access must come through a separately reviewed, narrowly scoped and actor-authorized interface, not generic `SECURITY DEFINER` grants. No new auth policies are introduced.

## Deployment sequence (not authorized by this PR)

1. Merge PR after **full clean local migration replay** and SQL tests; no mandatory remote staging.
2. Before applying any production DDL, verify **fresh backup** and **isolated restore readiness**. Inspect live schema/migration diff again, check App/Studio references, take baseline counts and snapshot IDs.
3. Obtain **explicit production migration approval**; apply exact GitHub migration in the OUTLAND canonical history through existing controlled migration workflow.
4. Verify table/RLS/FK constraints and the original 61 locations / 54 V2+V3 fact records / all quest releases. Check new research backfill count = 54 and franchise hypotheses link to real canonical franchise rows. Run negative `anon`/`authenticated` privileges.
5. Keep new app-facing features OFF until a separately tested Studio read/write boundary is created. No quest or multiplayer activation as part of the migration.

### Rollback and forward recovery

Schema migration is **additive**: normal rollback is to leave new private structures unused while preserving all prior data. If a clean revert is explicitly authorized, first export newly created data, then drop new dependent tables and new optional evidence columns and composite indexes in reverse dependency order. **Never automatically delete production research facts, canonical locations, quest drafts, releases or their media**. No destructive production rollback without separate approval.

### Residual limitations

- This first step defines registries and seeds the original 54 research dossiers/one-per-record franchise *hypotheses*. It does not autonomously verify each historical claim, validate every safe arrival waypoint, deduce a park hierarchy from coordinates, or generate final gameplay puzzles.
- The single-quest field walkthrough is the final human checkpoint; editorial AI research and safety reasoning continue beforehand without additional approval queues.
- SQL tests use a disposable local Postgres stack in GitHub CI. CI success does **not** mean a production migration has happened.