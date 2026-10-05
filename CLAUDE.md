# Claude Code instructions — OUTLAND repository / SIDEWORLD work

## Scope and authority
This repository currently hosts OUTLAND OS and COMPASS. SIDEWORLD is a NEW independent consumer platform for location-based adventures; OUTLAND is ONE optional universe on SIDEWORLD, not SIDEWORLD's parent. SIGNAL is a gameplay/lore trigger; The Parallel is a deeper narrative concept. Never rename the existing OUTLAND OS operational product to SIDEWORLD or assume the existing OUTLAND Platform Master Plan describes the new cross-universe SIDEWORLD ownership model.

For existing OUTLAND OS code, preserve working operational boundaries. For new SIDEWORLD features, use the SIDEWORLD decisions here and the reviewed SIDEWORLD architecture documents. If documents conflict, explicitly report the conflict rather than silently replacing historical decisions.

## Approved SIDEWORLD direction
- Consumer brand/app: SIDEWORLD; tagline: FOLLOW THE SIGNAL; positioning: Real-world adventures.
- OUTLAND is one universe among many. MVP may temporarily use sideworld.outland.one; that URL does not imply brand ownership.
- One canonical SIDEWORLD Universe registry is planned; never duplicate Universe identity across schemas.
- Narrative hierarchy: Universe → Franchise → Story, with canonical Characters, Factions and Lore. Theme is a reusable creative/gameplay treatment, not canonical story/character ownership.
- APPROVED V3.1 WORLD SPLIT: SIDEWORLD experience/content/demand Worlds and OUTLAND operational/investment Worlds are distinct concepts and may have distinct UUIDs:
  - planned `universe.worlds` = SIDEWORLD experience/content/demand contexts;
  - existing `shared.worlds` = OUTLAND operational/investment Worlds used by COMPASS/LAND, assets, Passport V0 and physical operations.
- Do not rename, repurpose or delete existing `shared.worlds`; preserve all UUIDs and dependencies. A future SIDEWORLD World must not silently replace an OUTLAND operational World.
- The two World registries may be linked M:N through an explicit reviewed bridge (working name `universe.world_operational_links`).
- Demand/capacity gaps in a SIDEWORLD Universe World may create an expansion signal. Creation of a new `shared.worlds` row requires explicit review/approval and then enters COMPASS/LAND; never auto-create operational Worlds from a metric threshold alone.
- Planned geography is City → Location, with Universe World ↔ City as M:N. Do not reuse legacy `universe.spots` as the new global Location model.
- `infrastructure.bases` is the accommodation-capacity entity, separate from businesses, physical POIs and collectibles/discoveries. Its two additive Phase 1B migrations are deployed and validated on both staging and production.
- Quest, video/YouTube and future game generation should share one canonical story/character/lore source rather than duplicate narrative truth per medium.
- Geography, quests, publication/versioning, player progress and generator metadata remain planned domains; do not bulk-create speculative tables.
- Founder builds software; AI produces content; Darko and Sara field-test initial quests. Initial market validation: Novi Sad, Belgrade and Dubai. ~1,000 cities after year one is a capability TARGET, not a projection.

## Existing implementation versus proposal
Read-only reconciliation refreshed on 2026-10-05: production has `shared.worlds`, `shared.assets`, `infrastructure.bases`, legacy `universe.nodes/frontiers/spots` and `passport.journeys/events`; refresh live state again before implementation. The existing `universe` schema is LEGACY OUTLAND V0 and creates a naming collision with the planned SIDEWORLD Universe/World domain; do not overwrite, reinterpret or drop V0 tables without a separately approved compatibility plan. A historical GREENHILL N·01 stay node remains preserved and auditable, with its accommodation representation already backfilled to `infrastructure.bases`.
Read current docs/architecture/OUTLAND_OS_CURRENT_STATE.md and docs/architecture/OUTLAND_PLATFORM_MASTER_PLAN.md as scoped OUTLAND OS references, not overriding SIDEWORLD brand architecture. Use `docs/architecture/SIDEWORLD_ARCHITECTURE_DATA_MODEL_V3_1.md` for the current cross-universe SIDEWORLD direction. The root README currently says OUTLAND is platform root: interpret this within existing OUTLAND OS, not as SIDEWORLD brand governance.

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
- For new architecture work, use a dedicated reviewed branch/PR. Do not append unrelated changes to closed historical PRs. Keep implementation PRs unmerged until independently reviewed and explicitly approved where production impact exists.
- Report file diffs, exact executed tests and results, blockers and commit SHA. If a check was not run, say so.
