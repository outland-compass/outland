# RAFTER OUTLAND OS HANDOFF V1

## 1. Purpose
This is the minimal approved handoff from RAFTER World into the central OUTLAND OS project. It does **not** authorize a general platform redesign. It describes only needs proven by the RAFTER concept.

## 2. RAFTER World definition for OS
World name: `RAFTER`.

RAFTER is a compact river-based OUTLAND experience designed for up to eight guest sleeping positions, preferably operating in an uncrewed/self-service mode. The guest uses Passport for temporary access and optional Mystery progression. The physical experience must remain safe and valuable when OS/Mystery technology is unavailable.

Legacy `RIVERKEEPER` must not be used as the World name.

## 3. Persistent achievement
- Technical code: `RIVER_KEEPER`.
- Guest-facing label: `ČUVAR REKE`.
- Achievement persists after temporary RAFTER accommodation access expires.

## 4. Domain boundaries
### RAFTER World owns
- physical layout and equipment;
- guest operating rules;
- Mystery narrative/content;
- Cartographer cabinet physical implementation;
- safety procedures;
- what events matter to the experience.

### OUTLAND OS should support
- persistent Passport identity;
- temporary access entitlement/window;
- credential revocation/reissue;
- minimal Mystery progression state;
- persistent achievement grant;
- event ingestion/synchronization;
- limited local/offline operation required for RAFTER;
- local device interaction for lock/light/audio/cabinet where explicitly needed.

### Not approved from RAFTER V1 alone
- generalized game engine;
- generalized IoT fleet management platform;
- Field Journal;
- broad loyalty platform;
- cross-world meta-game;
- custom booking engine;
- complex rules engine;
- computer-vision guest monitoring;
- safety-critical automation depending on cloud connectivity.

## 5. Passport requirements
Passport must support:
1. persistent guest identity;
2. credential usable at RAFTER;
3. temporary access bounded by reservation/check-in/check-out;
4. revocation of lost credential;
5. replacement/reissue without losing guest history/achievement;
6. offline/local verification sufficient for the defined pilot failure mode;
7. persistent achievement after access expiry.

Printed passport/booklet is not required as the primary V1 credential.

## 6. Prototype terminals
### Terminal A — RAFTER Entrance
Required behavior:
- read Passport credential;
- determine whether temporary access is valid;
- unlock/allow entry through local controller;
- record arrival/access event;
- start or activate guest's RAFTER Mystery context;
- remain usable under defined offline conditions.

### Terminal B — RAFTER Mystery
Required behavior:
- read Passport;
- read current RAFTER Mystery progression;
- validate current checkpoint/action;
- trigger local light/audio response;
- release the Cartographer cabinet when final condition is met;
- record/queue event for sync.

Exactly two fully functional terminals are sufficient for the first prototype. Additional checkpoints are deferred.

## 7. Minimal Mystery state
The OS only needs enough representation for the real RAFTER V1 progression:
- `TOK`
- `GLAS`
- `OBALA`
- `NOĆ`
- finale/cabinet eligibility
- completed / achievement granted

The final implementation may represent this differently internally; this handoff does not specify a database schema.

## 8. Minimum event set
Names below are conceptual, not an API contract:
- guest access activated;
- RAFTER arrival/check-in;
- credential accepted/denied;
- Mystery chapter/checkpoint completed;
- local feedback triggered;
- cabinet unlocked/opened;
- achievement granted;
- checkout/access expired;
- credential revoked/reissued;
- offline event queued/synced;
- optional device fault/needs-attention event.

Only store events that serve access, experience continuity, operations or evidence. Avoid telemetry for its own sake.

## 9. SENSE/local control requirements
RAFTER V1 justifies local control of:
- entrance lock/access actuator;
- Mystery light feedback;
- Mystery audio feedback;
- Cartographer cabinet actuator;
- basic device health/availability signals where operationally useful.

ESP32-class hardware is a valid prototype direction, not a mandatory final architecture.

## 10. Offline and fail-safe requirements
- Loss of internet must not strand a guest outside during a valid stay if local policy can safely verify access.
- Loss of internet must not prevent safe exit.
- Mystery events may queue for later synchronization.
- Mystery may degrade gracefully if device/cloud state is unavailable.
- Mechanical/operator override must exist for essential access and cabinet service.
- Fire/life-safety functions are outside dependence on OS.

## 11. Booking integration boundary
RAFTER V1 may originate reservations from Booking/Airbnb and/or direct/manual channels. OUTLAND OS needs a way to associate a confirmed stay with guest identity and temporary access lifecycle, but RAFTER does not justify building a full booking engine.

## 12. Minimal operational vertical slice
PASS-worthy vertical slice:
1. Create/recognize a guest Passport identity.
2. Associate guest with a RAFTER stay/access window.
3. Entrance terminal accepts valid credential and rejects invalid/expired/revoked credential.
4. Access continues under the defined offline mode.
5. Guest completes the minimal four-chapter Mystery progression using at least the Mystery terminal/local interactions.
6. Cabinet unlocks locally when eligible.
7. `RIVER_KEEPER / ČUVAR REKE` is granted persistently.
8. Checkout expires accommodation access without deleting achievement.
9. Lost credential can be revoked/reissued.
10. Mystery/OS failure never blocks safe exit or basic accommodation.

## 13. FAIL conditions
- Requires cloud connectivity for safe entry/exit during the intended offline case.
- Achievement disappears when access expires.
- Mystery can lock essential guest movement.
- Pilot requires building generalized engines not justified by RAFTER.
- Booking source must use a new custom booking product to make Passport work.
- Device architecture becomes safety-critical without mechanical fallback.

## 14. Required documentation updates in central OUTLAND OS project
After this handoff is approved, the OUTLAND OS development project should inspect and update, as applicable:
- Platform Master Plan — add RAFTER as the first concrete end-to-end vertical slice and clarify non-scope.
- Current State — distinguish what RAFTER requirements are documented vs actually implemented.
- Passport concept/current-state docs — align two-terminal prototype and access/achievement lifecycle.
- SENSE/current-state docs — record only the local control requirements actually justified by RAFTER.
- Mystery/current-state docs — add RAFTER's minimal chapter/state/event needs without inventing a generic game engine.
- World documentation index — point to the canonical RAFTER package.

Exact repository filenames/paths must be discovered from the real repository before editing.

# 15. Three-target migration matrix
| RAFTER concern | Main OUTLAND ChatGPT project | OUTLAND OS ChatGPT project | GitHub action after approval |
|---|---|---|---|
| World identity / RAFTER definition | Update canonical World source | Reference as first vertical slice | Add approved World docs |
| Physical platform / layout / BLOCKS | Full context | Only constraints relevant to access/SENSE/Mystery | Store under `docs/worlds/rafter/` |
| Operations / uncrewed model | Full context | Capture access/offline/local-response implications | Update World docs; platform docs only if affected |
| Legal/safety verification | Full register | Record safety boundary/non-dependence | Keep verification docs, avoid unsupported legal claims |
| Passport | World-level guest flow | Detailed RAFTER requirements | Update Passport/platform docs as needed |
| SENSE | Physical device needs | Minimal local-control requirements | Update SENSE/current-state docs only after repo inspection |
| Mystery | Full narrative/guest flow | Minimal state/events + cabinet interface | Update Mystery/platform docs without generic engine |
| Achievement | User-facing meaning | Persisted code/state requirement | Update platform docs/data definitions only if existing architecture supports it |
| Booking | Channel strategy | Access-lifecycle integration only | Do not add custom booking platform scope |
| Commercial model | Full economics | Non-functional context only | World docs only |

## 16. Handoff rule

## 17. Entrance-terminal canonical update — DECIDED 2026-09-06

- Terminal A serves the manual Passport door between the open Front Deck and enclosed River Room; it is not a stern or service-zone portal.
- Credential: OUTLAND Passport DESFire EV3 card presented to a concealed reader/antenna behind a tested non-metallic mask.
- Local chain: reader → local OUTLAND terminal → relay output → concealed fail-secure electric strike. Prototype reference: `ASSA ABLOY effeff 118, 10–24 V AC/DC, fail-secure`; final faceplate/variant remains `TO VERIFY`.
- On authorization, release the strike only for a short configured interval; the guest opens the door manually. Record authorization result and door-closed sensor state without making cloud availability a prerequisite.
- Required operational functions: administrative unlock, time-limited offline access, credential revocation/reissue, door-closed sensing and safe degradation.
- Interior exit is purely mechanical and independent of power, Passport, NFC, network, Mystery state and OUTLAND OS.
- Not V1: automatic/motorized door, hotel smart lock, generic RFID handle, visible keypad/screen, or a key-dispensing NFC box as the primary experience.
- Entrance UI follows the cross-World principle: “Ista nevidljiva OUTLAND tehnologija, drugačiji fizički portal svakog World-a.”
The OS team must distinguish **documented requirement** from **implemented capability**. This file authorizes analysis and alignment after owner approval; it does not imply that any code, schema, device firmware or repository change already exists.
