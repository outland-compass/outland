# RAFTER DECISION REGISTER V1

> **Alignment note — 2026-09-07:** Updated to incorporate owner-approved Floor Plan V2 decisions. Where older V1 wording conflicted, the 2026-09-07 decisions supersede it.

## Document control
- Version: V1
- Date: 2026-09-06
- Status: REVIEW DRAFT
- Canonical scope: significant RAFTER decisions and their lineage

| ID | Area | Decision | Status | Rationale | Source/order | Consequence |
|---|---|---|---|---|---|---|
| R-D001 | Identity | World name is `RAFTER`. | DECIDED | Better fit for the physical and experiential concept. | Latest naming decision | All World docs/UI use RAFTER. |
| R-D002 | Identity | `RIVER_KEEPER` is the technical achievement code; user-facing name is `ČUVAR REKE`. | DECIDED | Preserves useful legacy identity without confusing World name. | Latest Passport/Mystery decision | Code may remain stable while World is RAFTER. |
| R-D003 | Identity | `RIVERKEEPER` is no longer the World name. | SUPERSEDED | Replaced by RAFTER. | Later than legacy docs | Legacy references must be migrated. |
| R-D004 | Product | RAFTER is an OUTLAND World, not merely accommodation or a raft. | DECIDED | Product value comes from place, exploration, transformation, Passport and optional Mystery. | Consolidated project direction | Guest and OS docs must represent a complete World loop. |
| R-D005 | Commercial | Primary product is a curated RAFTER river experience / mini-expedition with optional overnight stay, not generic nightly accommodation. | DECIDED | Protects product identity and pricing logic. | Audit Gate 2 | Booking channels do not define product. |
| R-D006 | Location | Target launch geography is Novi Sad / Danube area; exact berth is not fixed. | DECIDED | Keeps the concept portable until legal berth is proven. | Audit Gate 1 | Ribarac is not hard-coded into World identity. |
| R-D007 | Capacity | Design target is up to 8 guests / 8 single sleeping positions. | DECIDED | Core physical program. | Audit Gate 1 | Commercial/navigation capacity remains TO VERIFY. |
| R-D008 | Platform | Compact catamaran is the working physical form. Exact dimensions remain TO VERIFY. | DECIDED / TO VERIFY | Latest design direction values compactness and cost control. | Later layout branches | No fixed LOA/beam may be presented as final. |
| R-D009 | Circulation | Earlier rule prohibiting passage through Inner Room is replaced by a continuous central longitudinal corridor through River Room, Inner Room and Service Core to stern. | SUPERSEDED → DECIDED | The night layout must preserve circulation without crossing sleeping surfaces. | Floor Plan V2 decision 2026-09-07 | Central corridor remains usable in day/dining/night/service/emergency modes. |
| R-D010 | Service | Service section is shortened/compacted but retains a central corridor. | DECIDED | Reduce footprint while preserving operations and circulation. | Later layout correction | Future plans must show the corridor. |
| R-D033 | Entrance | Main physical entrance into enclosed RAFTER is Front Deck → automatic main entrance → River Room. | DECIDED | Establishes clear arrival/security boundary. | Floor Plan V2 decision 2026-09-07 | Exact door construction remains TO VERIFY. |
| R-D034 | Passport / Access | Passport/NFC controls the automatic main entrance during normal guest access via local controller. | DECIDED | Makes Passport the normal guest access credential while retaining fail-safe safety boundary. | Floor Plan V2 decision 2026-09-07 | Safe exit must not depend solely on Passport/NFC, network/cloud or powered automation. |
| R-D035 | Spatial | River Room and Inner Room are separated by a lightweight sliding partition, not a heavy security/structural door. | DECIDED | Supports transformation without a heavy internal door. | Floor Plan V2 decision 2026-09-07 | Must preserve central corridor; exact construction TO VERIFY. |
| R-D036 | River Room | Dining capacity is 8 using folding/removable tables and 8 folding chairs. | DECIDED | Preserves River Room as flexible lounge/work/view/experience space. | Floor Plan V2 decision 2026-09-07 | Future drawings must not imply permanent dining furniture. |
| R-D037 | Drawing | Top view must read as one vertical boat-stack footprint per side; side/rear views show SUP/kayak/canoe vertical levels. | DECIDED | Prevents repeated misreading of rack arrangement. | Floor Plan V2 decision 2026-09-07 | Reinforces R-D012/R-D014. |
| R-D011 | Inner Room | Day mode opens strongly toward the river; night mode provides thermal, light and privacy isolation. | DECIDED | Enables transformable day/night product. | Inner Room design discussion | Final envelope system remains TO VERIFY. |
| R-D012 | Boats | Two symmetric external stern vertical racks, one port and one starboard, parallel to the catamaran. | DECIDED | Corrects prior plan errors and saves deck footprint. | Latest plan correction | Top view shows one stack per side. |
| R-D013 | Boats | Each rack: SUP top, kayak middle, tandem canoe bottom. | DECIDED | Final storage order. | Latest plan correction | Must be preserved in all drawings. |
| R-D014 | Boats | In top view, each side reads as one vertical stack, not three boats side-by-side. | DECIDED | Prevents repeated drafting error. | Latest explicit correction | Drawing QA rule. |
| R-D015 | BLOCKS | 8 single modular furniture units support day and night configurations. | DECIDED | Supports flexible space for up to 8 guests. | Final BLOCKS direction | Requires physical prototype. |
| R-D016 | BLOCKS | Backrest uses an external L element behind the back, engaging sewn pockets/sleeves in base and backrest. | DECIDED | Simple, repairable, non-invasive construction. | Latest BLOCKS correction | No hidden dock required. |
| R-D017 | BLOCKS | No hidden docks and no drilling through foam. | DECIDED | Simplifies fabrication and durability. | Latest BLOCKS correction | Prototype must preserve this constraint. |
| R-D018 | BLOCKS | 8 additional waterproof covers are required for wet-use/day-lounger mode. | DECIDED | Enables post-swim use without compromising internal covers. | Final BLOCKS direction | Include in CAPEX and storage planning. |
| R-D019 | Mystery | RAFTER Mystery is not a classical escape room. | DECIDED | Mystery supports exploration and stay instead of dominating it. | Mystery design discussion | Guest can have a full stay without completing it. |
| R-D020 | Mystery | No secret room; finale is a visible but locked Cartographer's cabinet. | DECIDED | Fits spatial constraints and story tone. | Latest Mystery correction | Earlier secret-room concepts are superseded. |
| R-D021 | Mystery | V1 chapter sequence: `TOK`, `GLAS`, `OBALA`, `NOĆ`. | DECIDED | Current narrative structure. | Mystery V1 concept | OS handoff uses this minimal state progression. |
| R-D022 | Mystery | Mystery must never gate essential accommodation, safe exit or basic access. | DECIDED | Life safety and graceful degradation. | Consolidated safety rule | Safety systems remain independent of game state. |
| R-D023 | Mystery | Mystery is integral to RAFTER identity but completion is optional for the guest. | DECIDED | Preserves product depth without coercive gameplay. | Audit Gate 2 | Flow supports non-playing guests. |
| R-D024 | Passport | Passport is persistent guest identity across OUTLAND Worlds. | DECIDED | Platform-level continuity. | Passport concept | RAFTER is first concrete pilot. |
| R-D025 | Passport | RAFTER prototype uses 2 fully functional terminals. | DECIDED | Smallest useful end-to-end pilot. | Passport concept | Entrance + Mystery terminal. |
| R-D026 | Passport | Lost credential must be revocable/reissuable; essential exit does not depend on NFC. | DECIDED | Safety and operational resilience. | Passport concept | Local/mechanical fail-safe required. |
| R-D027 | OS scope | Field Journal, general game engine, generalized IoT platform and bespoke booking engine are not V1 requirements. | DEFERRED | Avoid platform overdesign before real-world evidence. | Passport/OS discussions | Do not implement from RAFTER docs alone. |
| R-D028 | Operations | Preferred V1 commercial mode is uncrewed/self-service stay. | DECIDED | Lower OPEX and better pilot economics. | Audit Gate 2 correction | Remote management and local emergency response become critical. |
| R-D029 | Operations | Hosted stay is optional; skipper/driver is used when operation or law requires it. | DECIDED / TO VERIFY | Separate guest service from navigational/legal requirements. | Audit Gate 2 correction | Minimum legal crew remains TO VERIFY. |
| R-D030 | Booking | V1 may use Booking/Airbnb and/or simple direct booking; own OUTLAND booking engine is deferred. | DECIDED / DEFERRED | Prevents unnecessary software scope. | Audit Gate 2 | Reservation must still connect to Passport/access lifecycle. |
| R-D031 | CAPEX | Target V1 CAPEX €15k; working envelope €15–20k; >€20k requires explicit re-underwriting; €25k is stop/go ceiling, not approved budget. | DECIDED | Enforces experimental, value-engineered pilot economics. | Audit Gate 1 | All estimates/quotes measured against this gate. |
| R-D032 | Delivery | Software should follow real RAFTER needs, not drive the physical experience. | DECIDED | Project is a physical-world pilot first. | Consolidation brief | Phased plan delays non-essential platform work. |
