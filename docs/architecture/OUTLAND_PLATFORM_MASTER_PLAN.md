# OUTLAND Platform Master Plan v1.2

**September 2026**

> **Design the Universe. Build only the next real playable or operable loop.**

## 1. Top-level naming

- **OUTLAND** — master brand, destination network and overall experience.
- **OUTLAND OS** — the entire software platform.
- **OUTLAND Universe** — persistent story/game universe spanning physical Worlds, future video game, tabletop and connected interactions.
- **OUTLAND** may also become the consumer-facing title of the future video game; that game is an interface into the Universe, not the OS.
- **NOW·HERE** — optional inner-journey/presence layer.

## 2. Platform capabilities

| Capability | Responsibility | Technical direction | Posture |
|---|---|---|---|
| COMPASS / LAND | Property intelligence, DD, evaluation | `land` | NOW |
| SHARED | Small cross-domain spine | `shared` | NOW |
| BOOKING | Availability, reservations, rates/packages | `booking` | When real inventory is bookable |
| PASSPORT | Persistent person journey | `guest` / Passport boundary TBD by use case | When continuity is real |
| UNIVERSE ENGINE | Big Story, Worlds, Epics, Mysteries, sessions/progress | initially `game` | Design now; build tiny |
| SENSE | ESP32/devices, telemetry, commands | `sense` | With real hardware |
| OPS | Turnovers, cleaning, maintenance | `ops` | With real operations |
| WAYFINDER | Empty capacity → audience → offer → campaign → booking → learning | later domain | With real inventory/history |
| FINANCE | Property economics, CAPEX/OPEX, NOI | `finance` | With real financial flows |

## 3. OUTLAND Universe ontology

**Big Story → World → World Story → Epic → Mystery → Location → Interaction / Node**

Supporting concepts can include Artifacts/Items and Characters/Entities.

This is an ontology, **not an instruction to create a table for every level**.

### Meanings

- **Big Story** — overarching OUTLAND mythology.
- **World** — major narrative + physical/digital setting (GREENHILL, LOST SIGNAL, RAFTER...).
- **World Story** — self-contained narrative arc of one World.
- **Epic** — large playable chapter that can span several Mysteries and interfaces.
- **Mystery** — bounded optional playable adventure.
- **Location** — physical, digital or hybrid place where play happens.
- **Interaction / Node** — smallest actionable trigger: ESP32, RFID, NFC, QR, button, board piece, digital trigger.
- **Artifact / Item** — physical/digital object with game meaning.

## 4. One Universe, multiple interfaces

The same Universe can be experienced through:

- physical OUTLAND destinations,
- a future OUTLAND video game,
- board/card/tabletop play,
- lightweight web/mobile interactions.

Do not create separate mythologies or disconnected progression systems by default.

### 4.1 OUTLAND World visitor interface boundary

**World is a thin interface layer and does not own domain truth. It must not create substitute implementations of planned OUTLAND OS capabilities; domain logic and persistence remain with the responsible capability when its real build trigger is reached.**

## 5. PASSPORT

PASSPORT is not merely CRM. It represents the persistent journey of a person through OUTLAND.

It may eventually retain:

- Worlds visited and stays,
- selected Epic/Mystery progress,
- artifacts/achievements/unlocks,
- selected video-game/tabletop consequences,
- membership/privileges.

PASSPORT records persistent consequences.

It does **not** own Mystery logic, ESP32 state or reservation truth.

### Physical credential decision

The first physical OUTLAND Passport is a durable ID-1 card using an original NXP MIFARE DESFire EV3 4K credential with AES authentication. It is global across Worlds and remains with the person between visits.

The Passport belongs to an individual person. A reservation, stay or Mystery session may belong to a group or crew.

The card carries a secure pseudonymous credential, not the complete guest profile, access history or Mystery progress. OUTLAND OS remains the source of truth, so a lost credential can be revoked and replaced without losing the person's persistent journey.

This product decision does not authorize a complete PASSPORT implementation or a full `guest` schema.

## 6. SENSE

SENSE owns the physical infrastructure:

- ESP32 Game Nodes,
- sensors,
- relays,
- RFID/NFC,
- displays,
- environmental measurements,
- commands.

Example responsibility boundary:

**SENSE:** “RFID 4 detected”  
→ **Universe Engine:** “Mystery step completed”  
→ **PASSPORT:** “selected progress persisted”

SENSE can also support non-game operations such as:

- water level,
- leak/bilge,
- temperature,
- access,
- other physical/environmental state.

## 7. Cross-reality example

1. BOOKING establishes a valid GREENHILL stay.
2. Guest opts into an Epic/Mystery.
3. UNIVERSE ENGINE activates the playable session.
4. Guest uses a physical artifact at an ESP32 node.
5. SENSE reports the interaction.
6. UNIVERSE ENGINE advances the Mystery and requests any safe physical response.
7. PASSPORT persists the selected consequence.
8. A future OUTLAND video game may recognize that discovery.
9. A later LOST SIGNAL visit may carry selected continuity.

## 8. Anti-overbuild rule

### NO SPECULATIVE INFRASTRUCTURE

No table, service, API, UI, event bus, generic abstraction, AI agent or game-engine subsystem is built merely because the long-term Universe may need it.

Before implementation answer:

1. What real property/guest/booking/Mystery/device/operator use case needs this?
2. Why now?
3. What is the minimum persistent data?
4. What is the shortest end-to-end loop?
5. What PASS/FAIL proves value?
6. What evidence justifies expansion?

If the answer is:

> “We will probably need it later.”

Document it and **do not build it**.

## 9. Complexity budget

- Prefer one database and one deployable application until real need forces separation.
- Prefer bounded schemas and explicit tables over generic object frameworks.
- Do not build a generalized game engine before one real Mystery proves the state model.
- Do not build a video-game backend before a real digital playable loop exists.
- Synchronize only cross-interface consequences that create real value.
- Avoid queues, event buses, microservices and generalized rule engines without measured need.
- Create abstractions only after a pattern repeats in at least two real workflows.

## 10. Current technical baseline

- `public`: no application tables; functions/RPC/types remain.
- `shared`: 5 cross-domain tables.
- `land`: 20 COMPASS/property-intelligence tables + 5 views.
- Active development database: main OUTLAND Supabase project.
- Future `booking`, `game`, `sense`, `ops`, etc. schemas remain conceptual until triggered.

Naming:

`schema.table_name`

Rules:

- singular domain schema,
- plural entity table,
- `snake_case`.

Examples:

- `shared.worlds`
- `land.candidates`
- `booking.reservations`
- `game.sessions`
- `sense.devices`

## 11. Development lifecycle

**USE CASE → MINIMUM DATA → MINIMUM WORKFLOW → TEST → OPERATE → LEARN → EXPAND**

Stages:

**IDEA → DEFINED → PROTOTYPE → OPERATING → EXPAND → PLATFORMIZE**

## 12. Near-term roadmap

### NOW

Continue LAND/COMPASS.

Keep SHARED small.

### DESIGN NOW, BUILD TINY

Preserve the OUTLAND Universe ontology and prove it with:

**one real Mystery + one physical node + minimal persistent progress**

### BOOKING

Build when the first OUTLAND asset is genuinely approaching bookability.

### SENSE

Build when a real ESP32/device interaction is prototyped.

### PASSPORT

Build when real cross-session or cross-World continuity is needed.

### OPS / FINANCE / WAYFINDER

Build when real operations and data justify them.

### FUTURE

- full OUTLAND video game,
- richer tabletop integration,
- deeper cross-World continuity,
- Powered by OUTLAND,

only after the underlying real-world loops are proven.

### First Universe proof — RAFTER

A concrete first proof is the **RAFTER Passport Prototype V0.1**:

**one World + one Mystery + one Passport + two physical terminals + one persistent achievement**

Terminal 1 proves time-bounded accommodation access with controlled offline operation at the RAFTER physical boundary **Front Deck → automatic main entrance → River Room**. A valid Passport/NFC credential commands a local entrance controller to unlock/open the automatic main entrance. The normal automated entrance is not the sole safe-exit mechanism: emergency egress remains mechanically/manual possible independent of Passport/NFC, network/cloud and normal powered door automation.

Terminal 2 proves the minimal RAFTER Mystery progression `TOK → GLAS → OBALA → NOĆ`, local light/audio response and Cartographer cabinet actuation. Successful completion persists `RIVER_KEEPER` / `ČUVAR REKE` in the person's Passport journey after accommodation access expires.

These are **documented RAFTER requirements**, not claims that the capability is already implemented.

No full video game, generalized content editor, multiplayer platform, universal game engine, generalized IoT fleet platform or custom booking engine is required.

The prototype must derive the minimum real persistence model. It does not authorize complete `guest`, `game`, `sense` or `booking` schemas.

## 13. Safety

- Mysteries are optional, resettable and fail-safe.
- Never physically lock guests into rooms.
- Essential accommodation does not depend on game logic.
- SENSE/game failure degrades to a normal stay.
- RAFTER safe emergency egress must not depend on Passport/NFC, network/cloud or normal powered entrance automation.
- Water/weather safety can disable outdoor play and trigger a fallback experience.

## 14. Governance

This document controls platform scope.

Detailed module specifications are written only after a module's build trigger is met.

Meaningful architecture decisions update this plan or the Decision Log.

Database changes go through migrations.

> **The Universe can be big. Each build step must be small.**
