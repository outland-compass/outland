# Architecture documentation authority

This directory contains both current architecture and historical plans. When documents conflict, use the following precedence.

## Current SIDEWORLD authority

1. `SIDEWORLD_CANONICAL_UNIVERSE_FRANCHISE_ARCHITECTURE_V3_1.md`  
   Product/canon meaning of Universe, Franchise, Series, World, Theme, Activity, Quest and their relationships.

2. `SIDEWORLD_SCHEMA_V3_2_CANONICAL_ARCHITECTURE.md`  
   Current canonical database ownership/boundaries for `universe`, `geo`, `canon` and their relationship to existing OUTLAND operational data.

3. `SIDEWORLD_STUDIO_V0_IMPLEMENTATION_BLUEPRINT.md`  
   Current Studio/Canon Editor scope, implemented V0 boundaries and next implementation steps.

## Important current decisions

- SIDEWORLD is the independent platform.
- Initial Universes: OUTLAND, THE UNCHARTED, HEARTLINES, WONDERLANDS, TASTE.
- Beyond the Atlas is a Franchise inside THE UNCHARTED.
- World is a spatial/experiential container; GREENHILL is the reference example.
- A World can group multiple Quests, Locations, Activities, Discoveries and Base/pod capacity in the same coherent territory.
- Universe → World is 1:N.
- World ↔ City is N:M.
- `universe.universes` is the canonical Universe registry.
- `universe.worlds` is the canonical SIDEWORLD World registry.
- `shared.worlds` remains the OUTLAND/Compass operational registry and is bridged explicitly where needed.

## Historical documents

Older OUTLAND/SIGNAL plans remain in the repository for traceability. They must not override newer SIDEWORLD architecture when they contain superseded statements.

In particular, the September 2026 proposal that `shared.worlds` should be the single canonical World identity for all SIDEWORLD concerns is superseded.

## Development and delivery policy

The approved delivery policy is [`SIDEWORLD_DEVELOPMENT_POLICY_V1.md`](SIDEWORLD_DEVELOPMENT_POLICY_V1.md): production-first for low-risk changes, staging on demand, passing PR/CI checks, verified backup/restore readiness before direct production database migrations, and explicit authorization for production database changes.

## Change discipline

Meaningful product or architecture decisions should update the relevant current authority document in the same PR whenever practical. Implementation status must be labeled separately from product/canon decisions, and production changes still require explicit authorization.
