# Claude Code instructions — OUTLAND repository / SIDEWORLD work

## Scope and authority
This repository currently hosts OUTLAND OS and COMPASS. SIDEWORLD is a NEW independent consumer platform for location-based adventures; OUTLAND is ONE optional universe on SIDEWORLD, not SIDEWORLD's parent. SIGNAL is a gameplay/lore trigger; The Parallel is a deeper narrative concept. Never rename the existing OUTLAND OS operational product to SIDEWORLD or assume the existing OUTLAND Platform Master Plan describes the new cross-universe SIDEWORLD ownership model.

For existing OUTLAND OS code, preserve working operational boundaries. For new SIDEWORLD features, use the SIDEWORLD decisions here and the reviewed SIDEWORLD architecture documents. If documents conflict, explicitly report the conflict rather than silently replacing historical decisions.

## Approved SIDEWORLD direction
- Consumer brand/app: SIDEWORLD; tagline: FOLLOW THE SIGNAL; positioning: Real-world adventures.
- OUTLAND is one universe among many. MVP may temporarily use sideworld.outland.one; that URL does not imply brand ownership.
- **SIDEWORLD Schema V3.2 (founder-approved 2026-10-06; see `docs/architecture/SIDEWORLD_SCHEMA_V3_2_CANONICAL_ARCHITECTURE.md`):**
  - `universe.universes` is the canonical SIDEWORLD Universe registry. SIDEWORLD itself is the platform, not a row.
  - `universe.worlds` is the canonical SIDEWORLD World registry.
  - `shared.worlds` is the EXISTING OUTLAND/COMPASS operational World registry. It is not a SIDEWORLD identity. Never rename, repurpose, delete or repoint it. `land.*`, `shared.assets`, `infrastructure.bases`, `passport.journeys/events` and `shared.activities` keep referencing OUTLAND operational records.
  - `universe.world_outland_map` is the only, explicit bridge between a SIDEWORLD World and an OUTLAND operational World. Never infer identity from matching UUIDs or names, and never backfill it automatically.
  - Domains: `universe` (topology/themes), `geo` (real-world geography and provenance), `canon` (fictional IP truth). `signal` and SIDEWORLD Passport additions come later, by separate approval.
  - `universe`, `geo` and `canon` are private authoring schemas: RLS on, no grants to `anon`/`authenticated`/`service_role`, not in the Compass Data API schemas. Exposure is a separate reviewed step.
  - Do not create `places.base`; `infrastructure.bases` remains OUTLAND accommodation capacity.
- SUPERSEDED: the earlier `core.universes` / possible `core.worlds` / `core.universe_worlds` proposal. `core.*` is not used for SIDEWORLD topology. Older text that treats `shared.worlds` as the SIDEWORLD World identity is superseded too; it remains valid only as OUTLAND OS history. Do not create `signal.worlds` or other World registries.
- Do not describe `shared.worlds` as a parcel wishlist: `land.candidates` already represents investment candidates.
- `infrastructure.bases` is the accommodation-capacity entity, separate from businesses, physical POIs and collectibles/discoveries. Its two additive Phase 1B migrations have been applied and validated on staging and production.
- Geography, quests, themes, recurring characters, publication/versioning and player progress are planned domains; do not bulk-create speculative tables.
- Founder builds software; AI produces content; Darko and Sara field-test initial quests. Initial market validation: Novi Sad, Belgrade and Dubai. ~1,000 cities after year one is a capability TARGET, not a projection.

## Existing implementation versus proposal
Production and staging have `shared.worlds`, `shared.assets`, `infrastructure.bases` (+ legacy migration audit) and `passport.journeys/events`; refresh live state before relying on this snapshot. The legacy OUTLAND V0 tables `universe.nodes/frontiers/spots` and their four Passport columns are RETIRED (PR #31, deployed to staging and production on 2026-10-06, 19 migrations). The historical GREENHILL N·01 stay node survives only as its Base and audit snapshot, which must stay preserved and auditable. `universe.set_updated_at()` must remain: the `passport.journeys` trigger still depends on it. The V3.2 canonical tables in `universe`/`geo`/`canon` exist only on the branch until separately approved and deployed. Do not invent accommodation capacity, bookings or completed quests.
Read current docs/architecture/OUTLAND_OS_CURRENT_STATE.md and docs/architecture/OUTLAND_PLATFORM_MASTER_PLAN.md as scoped OUTLAND OS references, not overriding SIDEWORLD brand architecture. Check docs/architecture/SIDEWORLD_* on your working branch. The root README currently says OUTLAND is platform root: interpret this within existing OUTLAND OS, not as SIDEWORLD brand governance.

## Before editing
1. Confirm current branch, latest main, PR #29, working tree and migration history. Never overwrite uncommitted changes.
2. Inspect current schema, RLS, constraints, functions, migrations, app queries, tests and deployment consumers before proposing DB changes. Do not assume staging is active.
3. Distinguish VERIFIED code/database facts, APPROVED design and UNVERIFIED assumptions in summaries.
4. Prefer smallest playable/sellable vertical slice and low operational cost; avoid generic engines and speculative infrastructure.
5. When a founder discussion changes architectural direction, mark previous assumptions as superseded or under review in `CLAUDE.md` and relevant decision docs before implementing them. A proposal is not approval; never silently promote it to a migration.

## Phase 1B status — CLOSED (2026-10-04)
The two additive `infrastructure.bases` foundation/backfill migrations are deployed and validated on staging (from `63b0012`) and on production (from the PR #29 merge `0e91c7e`). Both record 18 migrations; existing worlds, candidates, Universe and Passport data were verified unchanged. Consult the execution evidence and refresh live state before relying on these facts. The normal checkout's Supabase CLI link to production was removed on 2026-10-04 (no `supabase/.temp/project-ref`); keep it unlinked, verify before any CLI work, and never use `db push --linked`. No narrative-world redesign or quest tables belong in PR #29. Existing legacy tables and Passport FKs remain in place. `infrastructure.*` is private and application grants are not yet implemented.

## Safety and delivery
- Never run production DDL, destructive operations, merges or deployments without separate explicit founder approval.
- Do not change historical applied migrations. Create new additive migrations.
- Do not use CASCADE for cleanup shortcuts.
- Do not expose credentials, service keys or private user data in docs, tests or output.
- PR #29 and #30 are merged. Subsequent legacy cleanup belongs on a separate bounded branch/PR; keep draft until reviewed.
- Report file diffs, exact executed tests and results, blockers and commit SHA. If a check was not run, say so.

## Legacy Universe V0 cleanup — CLOSED (2026-10-06)
`20261004140102_retire_legacy_universe_v0.sql` removed `universe.nodes/frontiers/spots` and the four Passport columns. It is deployed and validated on staging and production, and PR #31 is merged (`f6ec8a7`). Do not rework it unless a new regression proves it necessary. Base/audit records are now the only copy of the node data: never run `scripts/staging/sideworld-1b-rollback.sql` (it refuses), and never `migration repair --status reverted` the cleanup while its file is in the repository. `universe.set_updated_at` remains for the Passport journey trigger.
