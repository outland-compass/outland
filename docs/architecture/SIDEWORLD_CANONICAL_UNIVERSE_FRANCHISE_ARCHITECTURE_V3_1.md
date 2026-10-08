# SIDEWORLD — Canonical Universe & Franchise Architecture V3.1

**Project Decision Summary | October 2026**

**Status:** Working canonical architecture. This document is the product/canon source of truth for Universe, Franchise, Series, World, Theme, Activity, Quest and their relationships unless superseded by a later approved decision.

## 1. SIDEWORLD vision

SIDEWORLD is an independent consumer platform that transforms real-world locations into playable adventures across multiple fictional and experiential universes.

Brand architecture:

- **SIDEWORLD** — independent consumer platform and application.
- **SIGNAL** — shared gameplay trigger and recurring narrative mechanism.
- **The Parallel** — potential deeper narrative concept connecting different realities.
- **Universe** — independent canonical reality or experiential identity within SIDEWORLD.
- **OUTLAND** — one Universe on the platform, not its parent brand.
- Tagline: **FOLLOW THE SIGNAL.**

SIDEWORLD is one platform for adventures across many Universes, not one game with thematic skins.

## 2. Approved initial Universe portfolio

The initial selected portfolio contains five Universes:

1. **OUTLAND** — real-world adventure, nature, exploration and independence.
2. **THE UNCHARTED** — lost history, hidden knowledge, global mysteries and historical discovery.
3. **HEARTLINES** — couples, relationships, romance and shared experiences.
4. **WONDERLANDS** — family exploration, imagination and playful adventures.
5. **TASTE** — food, gastronomy, local culture and culinary exploration.

These five are approved product portfolio identities. They do not all need to launch simultaneously.

Future candidates such as ARCANA, FRACTURE, SHADOW NETWORK, ETERNALS and TOMORROW remain exploratory and are not initial portfolio commitments.

Universe names and commercial rights still require separate verification before public branding.

### OUTLAND

Existing World examples include:

- GREENHILL
- RAFTER
- ORIGIN

OUTLAND supports hiking, kayaking, camping, diving, snorkeling, climbing, cycling and exploration, plus physical destinations, accommodation capacity, equipment/services and demand-versus-capacity intelligence.

### THE UNCHARTED

**Primary Franchise:** Beyond the Atlas.

**Proposed Series:**

- The Lost Cartographers
- Timekeepers

**Working narrative/spatial candidates previously discussed:**

- The Lost Meridian
- The Sunken Kingdoms
- The Forgotten Routes

These names must not be forced into the World model unless they satisfy the final canonical World definition in this document.

### HEARTLINES

Dedicated to meaningful adventures for couples, including cooperative mysteries, shared choices, romantic discovery and personalized two-player experiences. It is an entertainment/adventure Universe, not a relationship-advice application.

### WONDERLANDS

Family and multigenerational adventures with age-adjusted difficulty, safer/shorter routes, cooperative play and child-friendly narrative/navigation.

### TASTE

Culinary exploration through food traditions, markets, bakeries, restaurants, regional dishes and cultural stories. Partner participation and purchases must not be mandatory for every Quest.

## 3. Beyond the Atlas — confirmed placement

The canonical structure is:

```text
SIDEWORLD
└── THE UNCHARTED
    └── Beyond the Atlas
        ├── The Lost Cartographers
        └── Timekeepers
```

Specifically:

- **Platform:** SIDEWORLD
- **Universe:** THE UNCHARTED
- **Franchise:** Beyond the Atlas
- **Series:** The Lost Cartographers, Timekeepers — proposed Series structure
- **Quests:** individual playable adventures across real-world cities

Beyond the Atlas is **not** an independent Universe and does **not** belong to OUTLAND.

### The Unbroken Line

The Unbroken Line is an overarching narrative mystery connecting multiple Series within Beyond the Atlas. It is **not a Series by default**.

Its precise long-term canonical role belongs in the Beyond the Atlas Franchise Bible. In the current V3.2 data model it can be represented as lore rather than being forced into `canon.series`.

## 4. Canonical entity definitions

### Universe

Highest-level independent canonical identity within SIDEWORLD. A Universe defines identity, positioning, rules, canon/lore where applicable, compatible Franchises and Worlds, characters/organizations, and visual/narrative guidelines.

Each Universe exists in exactly one canonical registry.

### Franchise

A long-term narrative and commercial intellectual property belonging to one Universe. A Franchise may contain multiple Series, story arcs, recurring characters, connected Quests, cross-city campaigns and media formats.

Franchise is not the same as World.

### Series

A connected narrative storyline within a Franchise. A Series establishes chronology, recurring characters, arcs/episodes, progression and continuity across Quests.

A Series may span many Cities and Worlds.

### World — final approved definition

A **World is a spatially defined SIDEWORLD territory / experience zone that groups multiple playable and physical elements within the same real-world space or coherent geographic area**.

A World can contain or support:

- multiple **Quests**;
- multiple **Locations / Stops**;
- multiple **Activities**;
- multiple **Discoveries**;
- relevant partner **Businesses**;
- physical **Base / accommodation capacity**;
- multiple OUTLAND pods/units or other physical capacity on that space where applicable.

**GREENHILL is the reference example:** one spatial World can contain accommodation capacity, several activities, several locations and several Quests on the same territory.

Therefore:

- World is a **spatial / experiential container**, not a synonym for Theme, Series or Franchise;
- World belongs to one canonical Universe;
- a World may span more than one City/geographic area when the territory genuinely requires it;
- a City may host multiple Worlds, including Worlds from different Universes;
- proposed THE UNCHARTED concepts such as The Lost Meridian are Worlds only if they represent a real spatial/experiential territory capable of holding multiple Locations, Activities and Quests.

### Character

A persistent canonical identity with one home Universe. A Character may appear in multiple Series, Worlds and Quests without duplication. Cross-Universe appearances require explicit authorization.

### Theme

Reusable creative identity, genre, style or storytelling configuration, such as historical mystery, romance, detective investigation, treasure hunting, magical discovery or culinary culture.

Theme is not a Universe.

### Activity

Reusable description of what the player physically or digitally does: walking, hiking, cycling, diving, snorkeling, climbing, kayaking, observation, decoding, puzzle solving, photography, etc.

Activity is independent of Universe identity.

### Quest

An individual playable adventure connecting narrative to real-world geography. A Quest may reference:

- one primary World;
- one City;
- an optional Franchise and Series;
- multiple Characters;
- multiple Activities;
- multiple Themes;
- multiple Discoveries.

Each published Quest must have a versioned, validated and immutable content package.

## 5. Canonical relationships

| Relationship | Cardinality |
|---|---|
| Universe → Franchise | 1:N |
| Universe → World | 1:N |
| Universe → Character | 1:N |
| Franchise → Series | 1:N |
| Franchise ↔ World | N:M |
| Series ↔ Character | N:M |
| World ↔ City | N:M |
| World → Quest | 1:N, primary World |
| Series → Quest | 1:N, optional |
| Quest ↔ Character | N:M |
| Quest ↔ Activity | N:M |
| Quest ↔ Theme | N:M |

Franchise and World are independent organizational axes. A Franchise may use several Worlds, while a World may support different Franchises within the same Universe.

Universe consistency must be validated across related entities. Cross-Universe Quests require an explicitly approved crossover mechanism.

## 6. Activities do not automatically become Universes

Diving, climbing and similar physical activities are shared Activities.

Examples:

- OUTLAND diving — real-world diving and underwater expeditions.
- THE UNCHARTED diving — hidden historical clues, submerged ruins or lost artifacts.
- HEARTLINES snorkeling — a couple-oriented shared discovery.

A dedicated underwater/climbing Universe may exist later only if it develops a genuinely independent identity, canon and World structure.

## 7. Shared SIDEWORLD gameplay architecture

All Universes share one platform foundation:

- player identity/profile;
- quest discovery/purchasing;
- City/location intelligence;
- navigation;
- puzzle and answer validation;
- hints;
- progress;
- achievements;
- Discoveries/collectibles;
- rewards/unlocks;
- SIGNAL;
- localization;
- analytics;
- versioned publication.

Universe-specific mechanics may extend this foundation, but SIDEWORLD must not become five separate quest engines.

## 8. Physical and geographic data model

Real-world geography stays separate from fictional/narrative identity.

- **City** — real geographic place that can host Quests from multiple Universes.
- **Location / Stop** — physical Quest anchor with coordinates and verification metadata.
- **Base** — accommodation or expedition capacity; not a generic commercial venue.
- **Business** — independent partner/service entity such as cafe, restaurant, bike rental, dive supplier or local operator.
- **Discovery** — distinct collectible/discoverable gameplay object; neither Business nor Base.
- **Player Progress** — completion, discoveries, achievements, progression and unlock state.

## 9. AI City Factory

Operating model:

- Founder develops and maintains the platform.
- AI generates and validates draft content.
- Founder and Sara perform initial field testing.
- Local reviewers/partners expand QA during scaling.

Initial validation markets:

- Novi Sad
- Belgrade
- Dubai

Malta remains useful prototype/product-learning material.

Generation flow:

1. Research City and verified POIs.
2. Select Universe and approved canon.
3. Select Franchise, Series, World and Theme where appropriate.
4. Select compatible Activities.
5. Generate story, route, puzzles and Discoveries.
6. Validate geography, safety, answers and canon consistency.
7. Editorial and field verification.
8. Publish immutable Quest versions.
9. Collect feedback/analytics.
10. Improve generation.

The approximately 1,000-city capability after the first year is a target, not a forecast or verified capability.

## 10. Canon governance

Reference hierarchy:

- **Universe Bible** — Universe identity, rules, history, canonical limitations.
- **Franchise Bible** — IP identity, major stories, organizations and conflicts.
- **Series Bible** — chronology, narrative arcs, episodes and recurring characters.
- **World Bible** — spatial identity, territory, relevant Locations, Activities, physical constraints and capacity.
- **Character Profiles** — identity, relationships, motivations, personality, voice and continuity.
- **Quest Content Package** — locations, puzzles, dialogue, answers, hints, rewards and version references.

The World Bible is a parallel constraint source, not subordinate to Series.

AI may Suggest or Draft, but may not silently rewrite or approve canonical facts.

## 11. Database and technical guardrails

- One canonical Universe registry.
- One canonical SIDEWORLD World registry.
- Do not duplicate Universe identities across schemas.
- Preserve OUTLAND operational functionality and existing dependencies.
- Prefer additive/backward-compatible migrations.
- Separate `base`, businesses and Discoveries.
- Inspect production schema/migrations/app dependencies before production changes.
- Test staging changes.
- Provide rollback plans.
- Never execute production modifications without explicit authorization.

Current implementation detail is documented separately in `SIDEWORLD_SCHEMA_V3_2_CANONICAL_ARCHITECTURE.md`; conceptual definitions in this document take precedence over older OUTLAND/SIGNAL planning notes where they conflict.

## 12. Commercial strategy

The initial portfolio addresses different audiences while sharing one platform:

| Universe | Primary audience | Main experience |
|---|---|---|
| OUTLAND | Outdoor enthusiasts | Expeditions and nature |
| THE UNCHARTED | Travelers and mystery fans | Historical adventure and narrative quests |
| HEARTLINES | Couples | Cooperative romantic exploration |
| WONDERLANDS | Families | Playful imaginative quests |
| TASTE | Food travelers | Culinary discovery |

Pricing and commercial models remain hypotheses until validated.

## 13. Decision status

### Approved / established

- SIDEWORLD is the independent platform.
- OUTLAND is one Universe, not umbrella brand.
- Initial Universes: OUTLAND, THE UNCHARTED, HEARTLINES, WONDERLANDS, TASTE.
- Beyond the Atlas is a Franchise in THE UNCHARTED.
- SIGNAL is shared gameplay/lore mechanism.
- The Parallel is a deeper narrative concept, not an initial Universe.
- World has the final spatial/experiential definition in §4.
- Universe → World is 1:N; World ↔ City is N:M.
- Diving/climbing are Activities.
- Base, Business and Discovery are separate.
- One shared SIDEWORLD gameplay engine supports multiple Universes.
- One canonical Universe registry and one canonical SIDEWORLD World registry.

### Proposed / not yet final canon

- The Lost Cartographers and Timekeepers as Series.
- Detailed Beyond the Atlas story content.
- Character roster, factions and chronology.
- The exact long-term representation of The Unbroken Line beyond its current overarching-mystery role.

### Working candidates

- The Lost Meridian
- The Sunken Kingdoms
- The Forgotten Routes

These are not canonical Worlds until each satisfies the approved World definition and is explicitly approved.

## 14. Next steps

1. Maintain Universe Bibles for the five selected Universes.
2. Produce THE UNCHARTED Universe Bible.
3. Produce Beyond the Atlas Franchise Bible.
4. Produce The Lost Cartographers Series Bible.
5. Build the Canon Context Builder against approved/active Studio records.
6. Build City Knowledge Base and first Novi Sad Quest through the scalable pipeline.
7. Keep technical implementation reconciled with this product/canon architecture.

## Final principle

**SIDEWORLD is one platform supporting multiple independent Universes, persistent Franchises, narrative Series, spatial Worlds, reusable Activities and location-based Quests.**

**OUTLAND · THE UNCHARTED · HEARTLINES · WONDERLANDS · TASTE**

**One platform. Many universes. Infinite adventures.**

**FOLLOW THE SIGNAL.**
