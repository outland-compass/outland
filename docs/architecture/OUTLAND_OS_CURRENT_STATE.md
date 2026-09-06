# OUTLAND OS — Current State

**Status date:** 2026-09-06  
**Purpose:** Operational handover and current-state reference for OUTLAND OS development.

> This document describes what exists now, what has been completed, what is intentionally deferred, and what should happen next.
>
> Long-term architecture is defined in `docs/architecture/OUTLAND_PLATFORM_MASTER_PLAN.md`.

---

## 1. Current objective

OUTLAND OS is the software platform that operates and connects the OUTLAND network.

The current objective is **not** to build the complete platform.

The development principle is:

> **DESIGN THE UNIVERSE. BUILD ONLY THE NEXT REAL PLAYABLE OR OPERABLE LOOP.**

Current priority:

1. Stabilize COMPASS.
2. Keep SHARED small.
3. Select and prove the next real vertical slice.
4. Avoid speculative implementation of future OUTLAND OS modules.

---

## 2. Canonical repository

GitHub repository:

`outland-compass/outland`

Default branch:

`main`

Current architecture source of truth:

`docs/architecture/OUTLAND_PLATFORM_MASTER_PLAN.md`

Platform Master Plan added to `main` in commit:

`4734a421973891957be2ddfc6a89f3d26b5c9496`

Only OUTLAND resources should be accessed from the OUTLAND OS development context.

Do not access unrelated GitHub repositories, organizations or software projects.

---

## 3. Current Supabase environment

Primary Supabase project:

- Name: `outland`
- Project ref: `huzcukdovavejejwohey`
- Region: `eu-west-1`
- PostgreSQL: 17

OUTLAND is currently early-stage and has no real production users.

For this phase, the main OUTLAND Supabase project serves as both:

- production database;
- active development database.

The local Supabase CLI is linked to:

`huzcukdovavejejwohey`

The local COMPASS environment also targets this project.

### Staging

A separate project exists:

- Name: `outland-staging`
- Ref: `clgpxvyflycudzhdzjlv`

It was used to validate the database namespace migration.

It is currently **not part of the normal development workflow** and does not need to remain synchronized with the main database.

Reintroduce active staging discipline when justified by real operational risk, such as:

- real guests/users;
- bookings or payments;
- risky migrations;
- continuous IoT/SENSE writes;
- multiple developers or major modules changing concurrently.

---

## 4. Current database architecture

Application data has been moved out of `public`.

### `public`

Contains:

- RPC/functions;
- PostgreSQL types;
- enums.

It contains **no application tables**.

### `shared`

Contains cross-domain entities.

Current tables:

- `shared.activities`
- `shared.assets`
- `shared.profiles`
- `shared.user_roles`
- `shared.worlds`

Total:

**5 tables**

### `land`

Owns the current COMPASS/property-intelligence domain.

Current tables:

- `land.score_dimensions`
- `land.world_dimension_weights`
- `land.world_score_criteria`
- `land.world_gate_definitions`
- `land.signals`
- `land.candidates`
- `land.candidate_sources`
- `land.candidate_price_history`
- `land.candidate_media`
- `land.candidate_economics`
- `land.evaluations`
- `land.evaluation_dimension_weights`
- `land.evaluation_items`
- `land.candidate_gates`
- `land.dd_items`
- `land.documents`
- `land.evidence_items`
- `land.notes`
- `land.visits`
- `land.decisions`

Total:

**20 tables + 5 views**

---

## 5. Database naming standard

Use:

`schema.table_name`

Rules:

- singular domain schema;
- plural entity table;
- `snake_case`.

Examples:

- `shared.worlds`
- `land.candidates`
- `booking.reservations`
- `game.sessions`
- `sense.devices`

All structural database changes must be implemented through migrations.

Before applying production-impacting database changes, use dry-run and appropriate verification.

---

## 6. Database namespace refactor — CLOSED

The COMPASS database namespace refactor is complete.

It moved:

- cross-domain entities → `shared`;
- COMPASS/property entities → `land`;
- application tables out of `public`.

It also updated:

- Supabase Data API schema exposure;
- frontend Supabase queries;
- generated TypeScript database types;
- seed data;
- schema/security verification;
- relevant public functions;
- audit handling for `evaluation_items`.

The refactor was validated before production cutover and subsequently applied to the main OUTLAND database.

Relevant migration files include:

- `202608200001_bootstrap_reference_data.sql`
- `202609020001_domain_schema_split.sql`
- `202609030001_fix_audit_evaluation_items_candidate_id.sql`

PR #1:

`refactor(db): split public schema into shared/land domain schemas`

was merged into `main`.

Merge commit:

`7645e8370e375f765683ca0649a3689d55429264`

### Decision

**Do not reopen this refactor unless a real operational defect requires it.**

---

## 7. Known deferred issue

There is a known pre-existing audit edge case involving deletion of `land.candidates`.

The candidate audit trigger attempts to write an activity referencing the candidate after that candidate has been deleted, which can conflict with the activity foreign key.

There is currently no candidate-delete workflow in the application.

Therefore:

**PARKED — NOT A CURRENT PRODUCT PROBLEM**

Do not redesign the audit architecture merely to solve this theoretical edge case.

Revisit only if candidate deletion becomes a real workflow requirement.

---

## 8. COMPASS current role

COMPASS is the current operational software capability inside OUTLAND OS.

It is the intelligence and decision-support layer for discovering, evaluating and performing due diligence on potential OUTLAND locations.

The current implementation includes concepts such as:

- signals;
- candidates;
- Worlds;
- scoring;
- gates;
- evaluations;
- due diligence;
- evidence;
- notes;
- visits;
- decisions;
- economics;
- candidate sources and price history.

COMPASS is **not the entire OUTLAND OS platform**.

Its database domain is currently represented by the `land` schema.

---

## 9. COMPASS development posture

The next COMPASS work should focus on **product stabilization**, not architecture expansion.

The immediate task is to classify existing COMPASS functionality into:

### KEEP

Working functionality that already supports the real property-intelligence workflow.

### FIX NOW

Actual defects or missing pieces that prevent the current workflow from being useful.

### PARK

Potential improvements that are useful but not currently blocking real operation.

### REMOVE LATER

Unused or obsolete complexity that may eventually be removed, but does not justify a cleanup project now.

Do not begin another broad COMPASS refactor without a concrete operational problem.

---

## 10. SHARED development posture

Keep `shared` deliberately small.

A table belongs in `shared` only when multiple real OUTLAND OS domains genuinely need to own or reference the same concept.

Do not use `shared` as a default location for entities whose future ownership is unclear.

If domain ownership is uncertain, wait until a real workflow clarifies it.

---

## 11. Future OUTLAND OS capabilities

The Platform Master Plan anticipates capabilities including:

- COMPASS / LAND
- BOOKING
- PASSPORT
- UNIVERSE ENGINE
- SENSE
- OPS
- WAYFINDER
- FINANCE

These are architectural directions, **not an implementation backlog**.

Do not create their schemas, services or infrastructure merely because they appear in the architecture.

Each capability requires a real build trigger.

---

## 12. OUTLAND Universe

The OUTLAND Universe is a persistent story/game universe that may span:

- physical OUTLAND destinations;
- future OUTLAND video game;
- board/card/tabletop experiences;
- web/mobile interactions.

Current conceptual ontology:

**Big Story → World → World Story → Epic → Mystery → Location → Interaction / Node**

Supporting concepts may include:

- Artifact / Item
- Character / Entity

This hierarchy is an ontology.

It is **not** a requirement to create one database table per concept.

---

## 13. Universe Engine / SENSE / PASSPORT boundary

Current responsibility model:

### SENSE

Owns physical devices, telemetry and commands.

Example:

`RFID detected`

### UNIVERSE ENGINE

Owns narrative/game state and Mystery logic.

Example:

`Mystery step completed`

### PASSPORT

Owns selected persistent person/player consequences.

Example:

`Discovery persisted for this person`

Conceptual flow:

**SENSE → UNIVERSE ENGINE → PASSPORT**

These responsibilities should not be collapsed without a demonstrated product reason.

---

## 14. Selected candidate for the next vertical slice

After COMPASS stabilization, the selected candidate for the next software experiment is the **RAFTER Passport Prototype V0.1**, a very small PASSPORT/SENSE/Universe Engine proof.

Target:

**one World + one Mystery + one Passport + two physical terminals + one persistent achievement**

Terminal 1 proves time-bounded accommodation access and controlled offline operation. Terminal 2 proves ordered Mystery progress and a safe physical response using light, audio and a test actuator. Successful completion persists `RIVER_KEEPER` / `ČUVAR REKE` after RAFTER access expires.

The purpose is to discover the minimum real requirements for:

- SENSE;
- Universe Engine;
- PASSPORT.

The purpose is **not** to implement these complete modules.

The concrete loop is now defined at product-concept level. No final schema should be designed until the prototype specification fixes the hardware flow, minimum persistence and executable tests.

The implementation-ready V0.1 specification is documented in `docs/product/RAFTER_PASSPORT_PROTOTYPE_V0_1.md`.

Specification status is **DEFINED**; implementation has not started. The next gate is the NFC security spike: one ESP32-S3, one PN7160 development board, two DESFire EV3 cards, AES mutual authentication and diversified keys. Hardware SKUs, suppliers, actual pricing and the final persistence model are not yet confirmed.

The prototype PASS criteria are:

1. the same DESFire card opens the entrance during a valid grant;
2. entrance access works during a controlled internet outage;
3. the Mystery terminal rejects invalid ordering;
4. a valid step triggers light, audio and a test actuator;
5. `RIVER_KEEPER` persists after check-out;
6. a credential can be revoked and replaced without losing the profile;
7. offline terminal events synchronize later;
8. failure degrades to a safe, normal stay.

---

## 15. BOOKING trigger

BOOKING should not be built simply because hospitality reservations will eventually be required.

Build BOOKING when an actual OUTLAND asset is genuinely approaching bookability.

The first Booking loop should be approximately:

**asset → availability → price → reservation → confirmation**

Do not initially build:

- generalized OTA synchronization;
- sophisticated revenue management;
- loyalty architecture;
- generalized payment abstraction;
- AI pricing infrastructure;
- speculative multi-property complexity.

Expand only from real operating evidence.

---

## 16. PASSPORT trigger

PASSPORT should expand when persistent identity or continuity becomes necessary for a real guest/player workflow.

Possible future responsibilities include:

- identity and consent;
- Worlds visited;
- stays;
- selected Mystery/Epic progress;
- artifacts/achievements;
- membership;
- privileges;
- selected cross-interface consequences.

PASSPORT does not own:

- booking truth;
- Mystery rules;
- ESP32/device state.

### Passport Product Concept V1 — ADOPTED

The first Passport is a durable ID-1 card using an original NXP MIFARE DESFire EV3 4K credential with AES authentication.

The Passport belongs to an individual person and remains with that person between visits. Reservations, stays and Mystery sessions may belong to a group or crew.

The card carries a secure pseudonymous credential rather than complete profile or progress state. OUTLAND OS remains the source of truth, allowing credential revocation and replacement without loss of the persistent journey.

The adopted concept is documented in `docs/product/OUTLAND_PASSPORT_PLATFORM_CONCEPT_V1.md`. Adoption of the concept does not authorize complete PASSPORT, BOOKING, SENSE or Universe Engine implementation.

---

## 17. SENSE trigger

SENSE should be implemented from real hardware interactions.

An ESP32-2432S028 device is available for prototyping.

The first implementation should prove one real end-to-end interaction before a generalized device platform is designed.

Possible later SENSE responsibilities include both game and operational functions:

- RFID/NFC;
- buttons;
- displays;
- relays;
- temperature;
- water level;
- leak/bilge detection;
- access;
- device health.

Do not build generalized IoT infrastructure before the prototype reveals actual requirements.

---

## 18. Explicitly not building now

Unless a concrete use case changes the priority, do **not** currently build:

- microservices;
- event buses;
- generalized workflow engines;
- generalized rules engines;
- generalized game engine;
- multiplayer infrastructure;
- universal physical/digital/tabletop synchronization;
- speculative AI-agent architecture;
- separate databases per domain;
- unnecessary staging/process infrastructure;
- full video-game backend;
- generalized content-management system for Mysteries.

Document future possibilities without implementing them.

---

## 19. Safety invariants

Mysteries must be:

- optional;
- resettable;
- fail-safe.

Never physically lock guests into rooms.

Essential accommodation must not depend on game logic.

SENSE or Universe Engine failure should degrade gracefully to a normal stay.

Safety-critical or irreversible physical automation requires stronger validation and appropriate fail-safe behavior.

---

## 20. Change safety

Default to read-only investigation.

Before implementation work:

1. inspect the current repository state;
2. identify unrelated local changes;
3. preserve them;
4. make focused changes only.

Never:

- use broad staging when unrelated changes exist;
- discard unrelated working-tree changes;
- force destructive Git operations without explicit reason;
- apply structural database changes outside migrations;
- access unrelated repositories or databases.

Production-impacting changes require explicit approval.

---

## 21. Current NOW / NEXT / LATER

### NOW

- Treat Platform Master Plan as architecture source of truth.
- Stabilize existing COMPASS product.
- Keep `shared` small.
- Continue operating the current `land` domain.
- Avoid new architecture work without a real trigger.

### NEXT

Subject to real-use-case validation:

- execute Gate A of the RAFTER Passport Prototype V0.1: the NFC security spike;
- prove DESFire AES mutual authentication and diversified keys before building relays or persistent schemas;
- then prototype two physical terminals: entrance and Mystery point;
- prove time-bounded offline access, ordered Mystery progress and one persistent achievement;
- derive minimum `game` / `sense` / Passport persistence from the operating prototype.

BOOKING can supersede this priority if a real OUTLAND asset becomes genuinely close to accepting reservations.

### LATER

As real operations justify them:

- richer PASSPORT;
- BOOKING expansion;
- OPS;
- FINANCE;
- WAYFINDER;
- richer Universe Engine;
- video-game integration;
- tabletop integration;
- broader SENSE infrastructure.

---

## 22. Decision rule for all new development

Before building anything substantial, answer:

1. **USE CASE** — Who needs this and for what real workflow?
2. **WHY NOW** — What current problem requires it?
3. **MINIMUM DATA** — What must actually persist?
4. **MINIMUM WORKFLOW** — What is the shortest end-to-end implementation?
5. **TEST** — What observable result constitutes PASS?
6. **EXPANSION TRIGGER** — What evidence would justify making it larger?

Then:

**USE CASE → MINIMUM DATA → MINIMUM WORKFLOW → TEST → OPERATE → LEARN → EXPAND**

If the primary justification is:

> “We will probably need it later.”

**Do not implement it yet.**

---

## 23. Starting point for the next OUTLAND OS session

The architecture/database namespace work is complete.

Do not start by redesigning the platform.

Start with:

> **Inspect the current COMPASS implementation and classify the existing product into KEEP / FIX NOW / PARK / REMOVE LATER.**

The objective is to determine whether COMPASS has any genuine blocking product work remaining before selecting the next real OUTLAND OS vertical slice.

---

**Canonical architecture:** `docs/architecture/OUTLAND_PLATFORM_MASTER_PLAN.md`

**Current-state document:** `docs/architecture/OUTLAND_OS_CURRENT_STATE.md`

> **The Universe can be big. Each build step must be small.**
