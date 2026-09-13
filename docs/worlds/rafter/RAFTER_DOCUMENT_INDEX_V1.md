# RAFTER DOCUMENT INDEX V1

> **Alignment note — 2026-09-07:** Updated to incorporate owner-approved Floor Plan V2 decisions. Where older V1 wording conflicted, the 2026-09-07 decisions supersede it.

## Document control
- Version: V1
- Date: 2026-09-07
- Status: OWNER-APPROVED RAFTER PROJECT SOURCE PACKAGE — aligned through Floor Plan V2 decisions of 2026-09-07; external repositories/projects require controlled handoff
- Owner: OUTLAND / RAFTER World
- Repository target: `docs/worlds/rafter/`

## Purpose
This index defines the authoritative RAFTER documentation package, its hierarchy, ownership of information, and migration path into the main OUTLAND ChatGPT project, the OUTLAND OS ChatGPT project, and the `outland-compass/outland` GitHub repository.

## Canonical hierarchy
1. `RAFTER_WORLD_MASTER_V1.md` — authoritative definition of the World, product boundaries, major decisions, phase plan and high-level risks.
2. Domain source files — authoritative detail for their domains:
   - `RAFTER_SPATIAL_AND_TECHNICAL_BRIEF_V1.md`
   - `RAFTER_GUEST_AND_MYSTERY_FLOW_V1.md`
   - `RAFTER_OPERATIONS_SAFETY_AND_LEGAL_V1.md`
   - `RAFTER_COMMERCIAL_MODEL_V1.md`
3. Registers — authoritative status tracking:
   - `RAFTER_DECISION_REGISTER_V1.md`
   - `RAFTER_OPEN_ITEMS_AND_VERIFICATION_V1.md`
4. `RAFTER_OUTLAND_OS_HANDOFF_V1.md` — deliberately narrow platform handoff; not a second World master.
5. This index — authoritative document map and supersession policy.

If two documents conflict, the newer explicitly approved decision wins. Until a newer package is approved, the Master governs product intent; the relevant domain file governs implementation detail; Decision Register records the decision lineage; Open Items records unresolved facts.

## Status vocabulary
- `DECIDED` — explicitly adopted.
- `ASSUMPTION` — working assumption used for planning.
- `OPEN` — owner/product decision still required.
- `TO VERIFY` — external, technical, legal, measurement or quotation evidence required.
- `SUPERSEDED` — replaced by a later decision.
- `DEFERRED` — intentionally postponed.

## Document map
| File | Canonical for | Status | GitHub readiness |
|---|---|---|---|
| `RAFTER_WORLD_MASTER_V1.md` | World definition, principles, scope, phase plan | OWNER-APPROVED | Ready for controlled handoff |
| `RAFTER_DECISION_REGISTER_V1.md` | Significant decisions and lineage | OWNER-APPROVED | Ready for controlled handoff |
| `RAFTER_OPEN_ITEMS_AND_VERIFICATION_V1.md` | Unresolved facts and verification gates | OWNER-APPROVED | Ready for controlled handoff |
| `RAFTER_SPATIAL_AND_TECHNICAL_BRIEF_V1.md` | Layout, circulation, physical platform, boat racks, BLOCKS interfaces | OWNER-APPROVED | Ready for controlled handoff |
| `RAFTER_GUEST_AND_MYSTERY_FLOW_V1.md` | Guest flow, Mystery V1, Passport touchpoints | OWNER-APPROVED | Ready for controlled handoff |
| `RAFTER_OPERATIONS_SAFETY_AND_LEGAL_V1.md` | Uncrewed operations, safety, berth/legal verification | OWNER-APPROVED | Ready for controlled handoff |
| `RAFTER_COMMERCIAL_MODEL_V1.md` | CAPEX discipline, revenue model, scenarios | OWNER-APPROVED | Ready for controlled handoff |
| `RAFTER_OUTLAND_OS_HANDOFF_V1.md` | Minimal RAFTER requirements for OUTLAND OS | OWNER-APPROVED | Ready after both ChatGPT projects are aligned |
| `RAFTER_DOCUMENT_INDEX_V1.md` | Package hierarchy and migration | OWNER-APPROVED | Ready for controlled handoff |

## Latest Floor Plan V2 alignment — 2026-09-07
The following owner-approved decisions supersede conflicting V1 wording:
- Main enclosed entrance is **Front Deck → automatic main entrance → River Room**.
- Passport/NFC controls the automatic main entrance during normal guest access through a local controller.
- Safe emergency egress remains independent of Passport/NFC, Mystery, network/cloud and normal powered automation.
- One continuous central longitudinal corridor connects Front Deck → River Room → Inner Room → Service Core → Dirty Deck/stern; passage through Inner Room is intentional and must remain clear in night mode.
- River Room ↔ Inner Room uses a **lightweight sliding partition**, not a heavy security/structural door.
- River Room dining for 8 uses folding/removable tables and 8 folding chairs.
- Top view shows one vertical boat-stack footprint per side; side/rear views show the three stacked craft levels.

## Superseded material
The following earlier concepts must not be treated as current RAFTER truth unless explicitly reintroduced:
- `RIVERKEEPER` as the World name.
- Larger ~14.5 m concept and later ~9–10 m dimensions as fixed specifications.
- €60–70k RAFTER V1 investment thesis.
- Fixed conventional sleeping-room-first layout.
- Secret Mystery room.
- Boat storage showing three vessels side-by-side on each stern side.
- Boat racks located as horizontal footprint inside the guest/dirty deck area.
- Earlier prohibition on circulation through the Inner Room. Current rule is a continuous central corridor through River Room → Inner Room → Service Core → stern.
- Oversized service block.
- Crew-dependent default stay.
- Hidden docking hardware or foam drilling for OUTLAND BLOCKS backrests.
- Printed Passport as the mandatory primary credential.
- Field Journal as a V1 requirement.
- Any Mystery mechanism that can block essential access, safe exit, or accommodation.

## Three-target migration sequence
### Target 1 — Main OUTLAND ChatGPT project
Update the RAFTER World source of truth: identity, spatial concept, BLOCKS, guest experience, Mystery intent, operating model, commercial model, decision register, superseded concepts and verification gates. Do not import software implementation detail.

### Target 2 — OUTLAND OS ChatGPT project
Use `RAFTER_OUTLAND_OS_HANDOFF_V1.md` to update platform-level understanding only: Passport lifecycle, SENSE/local control needs, Mystery state/events, persistent achievement, offline and safety boundaries, minimal vertical slice and explicit non-scope.

### Target 3 — GitHub `outland-compass/outland`
Only after Targets 1 and 2 are aligned. Inspect the repository's real current documentation structure through the GitHub connector, then add/update the approved RAFTER package and any platform master/current-state documents affected by the handoff. Do not assume paths beyond `docs/worlds/rafter/` until repository inspection confirms them.

## Proposed repository paths
All RAFTER package files should start under:

`docs/worlds/rafter/`

Recommended filenames are exactly those listed in this package.
