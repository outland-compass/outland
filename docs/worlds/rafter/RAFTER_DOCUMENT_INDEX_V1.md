# RAFTER DOCUMENT INDEX V1

## Document control
- Version: V1
- Date: 2026-09-06
- Status: REVIEW DRAFT — ready for owner review, not yet canonical in OUTLAND repositories
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
| `RAFTER_WORLD_MASTER_V1.md` | World definition, principles, scope, phase plan | REVIEW DRAFT | Ready after owner approval |
| `RAFTER_DECISION_REGISTER_V1.md` | Significant decisions and lineage | REVIEW DRAFT | Ready after owner approval |
| `RAFTER_OPEN_ITEMS_AND_VERIFICATION_V1.md` | Unresolved facts and verification gates | REVIEW DRAFT | Ready after owner approval |
| `RAFTER_SPATIAL_AND_TECHNICAL_BRIEF_V1.md` | Layout, circulation, physical platform, boat racks, BLOCKS interfaces | REVIEW DRAFT | Ready after owner approval |
| `RAFTER_GUEST_AND_MYSTERY_FLOW_V1.md` | Guest flow, Mystery V1, Passport touchpoints | REVIEW DRAFT | Ready after owner approval |
| `RAFTER_OPERATIONS_SAFETY_AND_LEGAL_V1.md` | Uncrewed operations, safety, berth/legal verification | REVIEW DRAFT | Ready after owner approval |
| `RAFTER_COMMERCIAL_MODEL_V1.md` | CAPEX discipline, revenue model, scenarios | REVIEW DRAFT | Ready after owner approval |
| `RAFTER_OUTLAND_OS_HANDOFF_V1.md` | Minimal RAFTER requirements for OUTLAND OS | REVIEW DRAFT | Ready after both ChatGPT projects are aligned |
| `RAFTER_DOCUMENT_INDEX_V1.md` | Package hierarchy and migration | REVIEW DRAFT | Ready after owner approval |

## Superseded material
The following earlier concepts must not be treated as current RAFTER truth unless explicitly reintroduced:
- `RIVERKEEPER` as the World name.
- Larger ~14.5 m concept and later ~9–10 m dimensions as fixed specifications.
- €60–70k RAFTER V1 investment thesis.
- Fixed conventional sleeping-room-first layout.
- Secret Mystery room.
- Boat storage showing three vessels side-by-side on each stern side.
- Boat racks located as horizontal footprint inside the guest/dirty deck area.
- Circulation through the Inner Room.
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

## Canonical update package — 2026-09-06

All nine RAFTER V1 documents in this index must be propagated together. The package includes decisions R-D033–R-D042 and verification items R-V032–R-V040 covering retained layout functions, Front Deck boarding, the Front Deck–River Room manual Passport portal, mechanical egress, River Room aluminum/polycarbonate sides, stern motor/rack exclusion zones and cost/engineering verification.

The following earlier variants are `SUPERSEDED`: guest boarding at the stern between motors; a stern Passport door; a Passport door between service zone and Inner Room; automatic/motorized doors; generic hotel smart locks/RFID handles; and an NFC key box as the primary RAFTER V1 experience.

Repository publication must not convert any `TO VERIFY` dimension, profile, panel thickness, strike faceplate, material mask, motor clearance, mass/stability value, quote or regulatory conclusion into a final specification.
All RAFTER package files should start under:

`docs/worlds/rafter/`

Recommended filenames are exactly those listed in this package.
