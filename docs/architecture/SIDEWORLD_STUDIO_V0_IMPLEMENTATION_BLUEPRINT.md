# SIDEWORLD Studio V0 — Implementation Blueprint

**Status:** Active implementation blueprint, updated 2026-10-08.  
**Scope:** Studio V0 / Canon Editor only. This document does not authorize production database writes.  
**Baseline:** SIDEWORLD Schema V3.2 is deployed to production; Studio V0-C/D1/D2 boundaries are implemented in the repository and deployed to staging only.  
**Product/canon source of truth:** `SIDEWORLD_CANONICAL_UNIVERSE_FRANCHISE_ARCHITECTURE_V3_1.md`.  
**Product sequence:** V3.2 Foundation → Studio/Canon Editor → Canon Context Builder → City Knowledge Base → First Story/Quest → Quest Compiler → Player App → Passport/Analytics.

---

## 1. Objective

Studio V0 is the first operational authoring surface for SIDEWORLD.

Its job is not to build the full City Factory yet. Its job is to make the V3.2 authoring foundation genuinely usable by the founder and later by AI-assisted editorial workflows.

Studio V0 must let an authorized editor:

1. create and edit canonical SIDEWORLD universes and worlds;
2. create and edit franchises, series, themes, characters, factions, lore facts and canon rules;
3. connect worlds to real cities;
4. inspect the current approved canon in one place;
5. clearly distinguish draft/proposed content from approved/active canon;
6. prepare structured inputs for the later Canon Context Builder;
7. never expose the private authoring schemas directly to the public/player client.

The first real content target is **THE UNCHARTED → Beyond the Atlas → The Lost Cartographers**, with **The Unbroken Line** represented as overarching lore rather than a Series, plus the first Novi Sad City work.

---

## 2. Verified baseline

The live V3.2 production foundation currently consists of 18 private, RLS-enabled tables across three schemas.

### 2.1 Canonical identity and creative structure

Existing tables:

- `universe.universes`
- `universe.worlds`
- `universe.themes`
- `universe.world_cities`
- `universe.world_outland_map`

Important invariants:

- SIDEWORLD is the platform and is **not** represented as a universe row.
- `universe.universes` is the one canonical SIDEWORLD Universe registry.
- `universe.worlds` is the canonical SIDEWORLD World registry.
- `shared.worlds` remains the OUTLAND/Compass operational registry.
- `universe.world_outland_map` is the optional explicit bridge between the two identities.
- `universe.world_cities` is the canonical World ↔ City many-to-many mapping.

### 2.2 Real-world knowledge

Existing tables:

- `geo.countries`
- `geo.cities`
- `geo.locations`
- `geo.location_facts`
- `geo.sources`
- `geo.fact_sources`

These tables already provide the correct foundation for a future City Knowledge Base: real locations, claims/facts, provenance, confidence, verification state and source relationships.

### 2.3 Fictional canon

Existing tables:

- `canon.franchises`
- `canon.series`
- `canon.characters`
- `canon.character_relationships`
- `canon.factions`
- `canon.lore_facts`
- `canon.canon_rules`

The schema already supports franchise/series structure, recurring characters, relationships, factions, lore facts, reveal phases, visibility and explicit AI continuity rules.

### 2.4 Security baseline

Verified live state:

- `universe`, `geo` and `canon` are private schemas.
- Their V3.2 tables are RLS-enabled.
- There are no current `anon`, `authenticated` or `service_role` table grants on these authoring tables.
- These schemas are not part of the public Data API exposure list.

**Consequence:** Studio V0 cannot simply point a browser Supabase client at the V3.2 authoring tables. A separately reviewed server-side authoring boundary is required.

---

## 3. V0 product boundary

Studio V0 intentionally does **not** include:

- quest runtime;
- stop/puzzle authoring;
- Quest Compiler;
- published quest payloads;
- player app;
- Passport/player progress;
- analytics;
- payment;
- autonomous AI write access;
- media generation pipeline;
- localization workflow;
- general creator marketplace.

Those belong to later verticals.

Studio V0 is successful when it can safely author and inspect the canonical material needed to build the first Canon Context Pack.

---

## 4. Recommended application shape

Create a separate app in the existing monorepo:

```text
apps/
  compass/
  world/
  sideworld-studio/
    web/
```

Current V0 stack:

- Next.js / React in `apps/sideworld-studio/web`;
- server-only Supabase RPC access;
- private access-key/session gate for the current founder-only V0 editor;
- route handlers as the browser-to-authoring write path;
- no browser possession of the service-role key;
- private/no-store responses;
- noindex/nofollow.

A stronger multi-editor identity model can replace the founder-only V0 gate when the product actually needs multiple editors.

### Why separate from Compass

Compass is an OUTLAND operational product. Studio is a SIDEWORLD authoring product spanning many universes. Combining their navigation, permissions and domain model would blur an architectural boundary that V3.2 was specifically designed to create.

---

## 5. Studio V0 navigation

Primary navigation:

```text
Studio
├── Dashboard
├── Universes
├── Canon
│   ├── Franchises
│   ├── Series
│   ├── Characters
│   ├── Factions
│   ├── Lore Facts
│   └── Canon Rules
├── Worlds
├── Themes
├── Cities
└── Canon Inspector
```

The later workspaces — Story, Quest Creator, Media, AI Generation, QA and Publishing — remain visible in architecture documentation but should not be implemented in V0.

---

## 6. Screen specification

### 6.1 Dashboard

Purpose: answer “what are we authoring and what is not yet approved?”

Cards:

- Universes by status
- Worlds by status
- Franchises by status
- Characters by canon status
- Lore facts by canon status
- Active canon rules
- Cities by verification status
- Recent edits

V0 does not need a generic activity log table yet; “recent edits” can be derived from `updated_at` where available.

### 6.2 Universe list / editor

Backed by `universe.universes`.

Editable:

- slug
- name
- visibility
- status
- description
- metadata

Guardrails:

- SIDEWORLD itself must never be created as a Universe row.
- archive rather than destructive delete in normal UI.
- changing a slug must display dependency impact.

### 6.3 World list / editor

Backed by `universe.worlds`.

Canonical product meaning: a World is a spatially defined SIDEWORLD territory/experience zone containing multiple playable or physical elements in the same coherent space. GREENHILL is the reference example. World is not a synonym for Franchise, Series or Theme.

Editable:

- universe
- slug
- name
- status
- summary
- metadata

Relations:

- city mappings from `universe.world_cities`
- optional OUTLAND bridge from `universe.world_outland_map`

The editor must visually distinguish canonical SIDEWORLD World identity from any linked `shared.worlds` operational identity.

### 6.4 Theme editor

Backed by `universe.themes`.

Editable:

- universe scope or global scope
- slug
- name
- description
- status
- style profile

V0 JSON editing can use structured textareas with schema validation rather than building a bespoke form for every style-profile field.

### 6.5 Franchise editor

Backed by `canon.franchises`.

Editable:

- universe
- slug
- name
- description
- status
- canon version
- metadata

V0 convention:

- `draft` = editable work
- `active` = currently canonical franchise container
- `archived` = no longer active

Changing `canon_version` should be deliberate and never happen automatically on every text edit.

### 6.6 Series editor

Backed by `canon.series`.

Editable:

- franchise
- optional theme
- slug
- name
- premise
- status
- sort order
- metadata

For the first narrative stack, **The Lost Cartographers** belongs here.

### 6.7 Character editor

Backed by `canon.characters`.

Editable sections:

- Identity
- Role / bio
- Canon status
- Personality
- Knowledge
- Voice
- Visual profile
- AI rules
- Metadata

The structured JSON profiles are important inputs to the later Canon Context Builder and should not be flattened into one prose biography.

### 6.8 Character relationships

Backed by `canon.character_relationships`.

Editable:

- character A
- character B
- relationship type
- description
- canon status
- valid-from phase
- valid-to phase
- metadata

Prevent self-relationships in the UI in addition to the database constraint.

### 6.9 Faction editor

Backed by `canon.factions`.

Editable:

- franchise
- slug
- name
- faction type
- description
- visibility
- canon status
- metadata

### 6.10 Lore Facts

Backed by `canon.lore_facts`.

Editable:

- franchise
- optional series
- stable fact key
- statement
- canon status
- reveal phase
- visibility
- metadata

This is the primary V0 structure for statements that AI may use as fictional truth.

**The Unbroken Line should be modeled here initially as an overarching mystery/lore structure unless later story architecture introduces a dedicated arc entity. It should not be forced into the Series table.**

### 6.11 Canon Rules

Backed by `canon.canon_rules`.

Editable:

- franchise
- optional series
- optional character
- rule type
- rule text
- severity
- status
- metadata

Examples:

- character knowledge limits;
- forbidden contradictions;
- tone constraints;
- reveal restrictions;
- world continuity rules.

These rules are the hard guardrail layer for the future Canon Context Builder.

### 6.12 City list / editor

V0 uses the existing `geo` foundation.

Backed by:

- `geo.countries`
- `geo.cities`

Editable city fields:

- country
- slug
- name
- region
- timezone
- default locale
- latitude / longitude
- status
- verification status
- metadata

Location/fact/source editing can remain read-only or minimal in the first Studio V0 slice and expand in the City Knowledge Base milestone.

### 6.13 Canon Inspector

This is the most important read surface in V0.

Filters:

- universe
- franchise
- series
- character
- canon status
- visibility
- rule severity

Output groups:

1. Universe identity
2. World identity
3. Theme/style
4. Franchise
5. Series
6. Characters
7. Character relationships
8. Factions
9. Lore facts
10. Canon rules

The Inspector should show an explicit badge for every record:

- DRAFT
- PROPOSED
- APPROVED / ACTIVE
- RETIRED / ARCHIVED

No AI generation in V0 should silently change these records.

---

## 7. Canon approval semantics

The current schema uses two status families:

### Container status

Used by universes, worlds, themes, franchises and series:

`draft | active | archived`

### Canon-item status

Used by characters, relationships, factions and lore facts:

`draft | proposed | approved | retired`

Canon rules use:

`draft | active | retired`

Studio V0 should respect these existing values rather than introducing a second approval vocabulary.

UI language can normalize them visually:

- Draft
- Proposed
- Canonical / Active
- Retired / Archived

But writes must preserve the actual table-specific enums/check values.

---

## 8. AI behavior in Studio V0

AI is optional assistance, not authority.

V0 interaction modes:

- **Suggest** — produces alternatives but writes nothing.
- **Draft** — can fill an editable draft form after explicit user action.
- **Approve** — always human action; AI cannot perform it silently.

For V0, AI calls should receive only explicitly selected context.

Do not yet implement autonomous “read all canon and mutate records” behavior.

---

## 9. Canon Context Builder contract — prepare now, implement next

Studio V0 should be designed so the next milestone can compile a deterministic context pack without schema redesign.

Proposed context-pack structure:

```json
{
  "context_version": 1,
  "universe": {},
  "worlds": [],
  "theme": {},
  "franchise": {},
  "series": {},
  "characters": [],
  "relationships": [],
  "factions": [],
  "lore": [],
  "rules": [],
  "city": {},
  "generation_constraints": {}
}
```

Selection rules for the future Builder:

- only canonical/active records by default;
- explicit opt-in for draft/proposed material;
- visibility/reveal restrictions respected;
- rules ordered by severity;
- stable IDs and canon version included;
- deterministic ordering;
- source record IDs preserved for traceability.

V0 should therefore keep structured records clean instead of moving knowledge into free-form prompts.

---

## 10. Server-side authoring boundary

The private-schema boundary is now implemented using narrow `public` RPCs called only by the Studio server.

Current flow:

```text
Browser
  ↓ private Studio session + validated form/API request
SIDEWORLD Studio server
  ↓ server-only service-role credential
allowlisted public RPC
  ↓ SECURITY DEFINER
private universe / geo / canon schemas
```

Current security properties:

- `universe`, `geo` and `canon` remain outside the Data API schema exposure list;
- browser roles do not receive direct schema/table privileges;
- browser roles cannot execute Studio RPCs;
- only `service_role` can execute the Studio read/write RPCs;
- `service_role` still has no direct `USAGE` on the private authoring schemas;
- service-role credential remains server-only;
- mutation handlers validate entity payloads before RPC calls;
- no raw SQL input is accepted from the browser.

The V0-C read boundary is `public.sideworld_studio_read_model(text)`.

V0-D1/D2 add narrow save RPCs for Universe, Franchise, Series, Lore, Canon Rules, Worlds, Themes, Characters, Factions, Country, City and World↔City relationships.

---

## 11. Database change assessment

### 11.1 No new domain tables were required for Studio V0 authoring

The V3.2 domain tables were sufficient for the initial Canon Editor. Studio access was added through narrow RPC functions rather than by exposing the private schemas.

### 11.2 Implemented access migrations

Repository migrations now include:

- `202610070001_sideworld_studio_read_boundary.sql`
- `202610070002_sideworld_studio_authoring_boundary.sql`
- `202610070003_sideworld_studio_world_city_canon_authoring.sql`

These migrations are additive. They add server-only RPC boundaries and do not add raw `universe`, `geo` or `canon` schemas to the Data API exposure list.

**Staging:** V0-C/D1/D2 migrations are deployed and security-validated.  
**Production:** Studio access migrations are not authorized/deployed by this documentation update.

### 11.3 Deferred tables

Do not add editor audit logs, canon snapshots, context-pack caches, AI job tables, media/story/quest/publication tables until a concrete workflow needs them.

---

## 12. Proposed V0 API surface

Browser-facing Studio handlers should be application APIs, not raw database proxies.

Example route set:

```text
/api/studio/universes
/api/studio/worlds
/api/studio/themes
/api/studio/franchises
/api/studio/series
/api/studio/characters
/api/studio/relationships
/api/studio/factions
/api/studio/lore
/api/studio/rules
/api/studio/cities
/api/studio/canon-inspector
```

Each resource gets only the methods V0 needs:

- GET collection
- GET item
- POST create
- PATCH edit
- archive/retire action

Avoid hard DELETE for canonical content in normal Studio V0 flows.

---

## 13. Proposed repository implementation

```text
apps/sideworld-studio/web/
  app/
    (studio)/
      page.tsx
      universes/
      worlds/
      themes/
      canon/
        franchises/
        series/
        characters/
        factions/
        lore/
        rules/
      cities/
      inspector/
    api/studio/
  components/
    entity-table/
    entity-form/
    status-badge/
    json-field-editor/
    relationship-picker/
  lib/
    auth/
    db/
    validation/
    studio/
  tests/
```

Root scripts to add only when implementation begins:

```json
{
  "build:studio": "...",
  "typecheck:studio": "...",
  "test:studio": "..."
}
```

Do not replace Compass build scripts.

---

## 14. V0 data-entry order

The first real Studio content should be entered in dependency order:

1. Universe — **THE UNCHARTED**
2. World(s), only where a spatial World has actually been approved
3. Theme, where useful
4. Franchise — **Beyond the Atlas**
5. Series — **The Lost Cartographers** (proposed Series structure)
6. Core characters
7. Character relationships
8. Factions
9. Lore facts, including the **Unbroken Line** mystery
10. Canon rules
11. Serbia / Novi Sad geo record
12. World ↔ Novi Sad mapping if the story/world requires it

Only after this structure reads coherently in Canon Inspector should we build the Canon Context Builder.

---

## 15. Acceptance criteria — Studio V0

Studio V0 is complete when:

- an authorized editor can sign in;
- private V3.2 schemas remain non-public;
- editor can CRUD-with-archive the V0 entities through server-only handlers;
- no direct browser write exists to `universe`, `geo` or `canon`;
- all existing database constraints are respected;
- canonical status is visibly distinct from draft/proposed status;
- Canon Inspector can render a coherent selected canon tree;
- BEYOND THE ATLAS / The Lost Cartographers can be represented without schema hacks;
- The Unbroken Line can exist as overarching lore without pretending to be a Series;
- Novi Sad can be represented as real-world city truth separately from fictional canon;
- no quest/player/passport schema is prematurely added;
- tests prove private authoring schemas did not become public Data API schemas.

---

## 16. Implementation sequence and current status

### Studio V0-A — Application shell — IMPLEMENTED

- separate `apps/sideworld-studio/web`;
- private access gate/session;
- Studio navigation/shell;
- Studio CI.

### Studio V0-B — Read contract / Canon Inspector — IMPLEMENTED

- typed read contract;
- non-production fixture;
- Canon Inspector;
- server-only data-source abstraction.

### Studio V0-C — Private read boundary — IMPLEMENTED, STAGING DEPLOYED

- service-role-only read RPC;
- private schemas remain outside Data API exposure;
- staging smoke/security validation passed.

### Studio V0-D1/D2 — Authoring boundary and editor — IMPLEMENTED, STAGING DEPLOYED

- founder-only private Studio session boundary;
- validated authoring API;
- save RPCs for canonical containers/canon/geo;
- World↔City authoring;
- staging security validation passed.

### Studio V0-D3 — Complete read model — IN REVIEW

The read model is being completed so Worlds, Themes and World↔City mappings read back through the same canonical Inspector contract.

### Studio V0-E — First canonical dataset — NEXT

Enter only decisions with approved status:

- Universe — **THE UNCHARTED**;
- Franchise — **Beyond the Atlas**;
- Serbia / Novi Sad geographic truth;
- proposed Series/lore only with their correct status labels;
- no speculative World rows until the specific spatial Worlds are approved under the final World definition.

Then proceed to **Canon Context Builder V0**.

---

## 17. Decision summary

### Approved / already established

- SIDEWORLD is the platform; OUTLAND is one universe.
- canonical Universe and World registries live in `universe`.
- real-world truth/provenance lives in `geo`.
- fictional IP canon lives in `canon`.
- Studio comes before Quest Compiler/player implementation.
- AI may suggest/draft but may not silently approve canon.
- published quests will later be immutable.
- authoring schemas remain private.

### Proposed by this blueprint

- separate `apps/sideworld-studio/web` application;
- Next.js server-side authoring boundary;
- service-role-only private-schema access through a future additive migration;
- Studio V0 scope and screens;
- Canon Inspector as the key V0 read surface;
- no new domain tables before a demonstrated need.

### Explicitly not authorized

- any production migration;
- any production data seed;
- any API exposure change;
- any production Studio deployment;
- any destructive database change.

---

## 18. Immediate next engineering task

1. Finish and merge the V0-D3 complete read-model work after CI/review.
2. Keep the Studio pointed at staging while authoring workflows are still evolving.
3. Seed the approved THE UNCHARTED → Beyond the Atlas dependency chain in staging.
4. Preserve proposed/working-candidate statuses instead of promoting them to canon automatically.
5. Build the deterministic Canon Context Builder next.
6. Keep production Studio migrations/data behind separate explicit authorization.
