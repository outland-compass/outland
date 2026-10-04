# Claude Code instructions — OUTLAND repository / SIDEWORLD work

## Scope and authority
This repository currently hosts OUTLAND OS and COMPASS. SIDEWORLD is a NEW independent consumer platform for location-based adventures; OUTLAND is ONE optional universe on SIDEWORLD, not SIDEWORLD's parent. SIGNAL is a gameplay/lore trigger; The Parallel is a deeper narrative concept. Never rename the existing OUTLAND OS operational product to SIDEWORLD or assume the existing OUTLAND Platform Master Plan describes the new cross-universe SIDEWORLD ownership model.

For existing OUTLAND OS code, preserve working operational boundaries. For new SIDEWORLD features, use the SIDEWORLD decisions here and the reviewed SIDEWORLD architecture documents. If documents conflict, explicitly report the conflict rather than silently replacing historical decisions.

## Approved SIDEWORLD direction
- Consumer brand/app: SIDEWORLD; tagline: FOLLOW THE SIGNAL; positioning: Real-world adventures.
- OUTLAND is one universe among many. MVP may temporarily use sideworld.outland.one; that URL does not imply brand ownership.
- One canonical Universe registry is PLANNED at `core.universes`, not verified as deployed.
- `shared.worlds` is the EXISTING OUTLAND/COMPASS operational World registry, NOT an approved permanent canonical registry for SIDEWORLD narrative worlds. Preserve existing UUIDs, data and COMPASS dependencies; do not rename, repurpose or delete it in PR #29.
- ARCHITECTURE DIRECTION UNDER EVALUATION: decouple SIDEWORLD narrative worlds from OUTLAND operational/investment records. A separate `core.worlds` and explicit mapping may be appropriate, but their precise semantics, ownership, cardinality and naming are NOT approved. Do not create `core.worlds`, `signal.worlds` or a mapping table without a separate founder-approved design and dependency audit. Do not describe `shared.worlds` as a parcel wishlist: `land.candidates` already represents investment candidates.
- One canonical Universe registry is planned; never duplicate universes across schemas. `core.universe_worlds` was an earlier proposal tied to the old world-registry assumption and must be revisited, not automatically implemented.
- `infrastructure.bases` is the accommodation-capacity entity, separate from businesses, physical POIs and collectibles/discoveries. Its two additive Phase 1B migrations have been applied and validated on staging only.
- Geography, quests, themes, recurring characters, publication/versioning and player progress are planned domains; do not bulk-create speculative tables.
- Founder builds software; AI produces content; Darko and Sara field-test initial quests. Initial market validation: Novi Sad, Belgrade and Dubai. ~1,000 cities after year one is a capability TARGET, not a projection.

## Existing implementation versus proposal
As verified during Phase 1B, production has `shared.worlds`, `shared.assets`, `universe.nodes/frontiers/spots` and `passport.journeys/events`; refresh live state before relying on this snapshot. The universe schema is LEGACY OUTLAND V0, not the new core.universes registry. A historical GREENHILL N·01 stay node must be preserved and auditable. Do not invent accommodation capacity, bookings or completed quests.
Read current docs/architecture/OUTLAND_OS_CURRENT_STATE.md and docs/architecture/OUTLAND_PLATFORM_MASTER_PLAN.md as scoped OUTLAND OS references, not overriding SIDEWORLD brand architecture. Check docs/architecture/SIDEWORLD_* on your working branch. The root README currently says OUTLAND is platform root: interpret this within existing OUTLAND OS, not as SIDEWORLD brand governance.

## Before editing
1. Confirm current branch, latest main, PR #29, working tree and migration history. Never overwrite uncommitted changes.
2. Inspect current schema, RLS, constraints, functions, migrations, app queries, tests and deployment consumers before proposing DB changes. Do not assume staging is active.
3. Distinguish VERIFIED code/database facts, APPROVED design and UNVERIFIED assumptions in summaries.
4. Prefer smallest playable/sellable vertical slice and low operational cost; avoid generic engines and speculative infrastructure.
5. When a founder discussion changes architectural direction, mark previous assumptions as superseded or under review in `CLAUDE.md` and relevant decision docs before implementing them. A proposal is not approval; never silently promote it to a migration.

## Phase 1B status — PR #29
The two additive `infrastructure.bases` foundation/backfill migrations were deployed and validated on staging on 2026-10-04 from approved SHA `63b0012`. Staging recorded 18 migrations and preserved seven candidates; consult the execution evidence and refresh live state. PR #29 remains subject to independent review and explicit merge approval. Production was NOT migrated as part of Phase 1B. The normal checkout's Supabase CLI link to production was removed on 2026-10-04 (no `supabase/.temp/project-ref`); keep it unlinked, verify before any CLI work, and never use `db push --linked`. No narrative-world redesign or quest tables belong in PR #29. Existing legacy tables and Passport FKs remain in place. `infrastructure.*` is private and application grants are not yet implemented.

## Safety and delivery
- Never run production DDL, destructive operations, merges or deployments without separate explicit founder approval.
- Do not change historical applied migrations. Create new additive migrations.
- Do not use CASCADE for cleanup shortcuts.
- Do not expose credentials, service keys or private user data in docs, tests or output.
- Commit changes on the existing feature branch and update PR #29, not a competing PR; keep draft until independently reviewed.
- Report file diffs, exact executed tests and results, blockers and commit SHA. If a check was not run, say so.
