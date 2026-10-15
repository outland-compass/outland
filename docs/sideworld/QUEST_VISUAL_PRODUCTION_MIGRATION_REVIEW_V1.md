# SIDEWORLD Quest Visual Production — Proposed Additive DB V1

**Status: DESIGN/PR ONLY — not production-authorized or executed.**
Owner: OUTLAND migrations. Consumers: existing SIDEWORLD Studio + Player.

## Read-only pre-change audit (15 Oct 2026)

- Production contains canonical \`canon.quest_drafts\`, \`canon.quest_draft_revisions\`, \`canon.quest_releases\`, \`canon.characters\`, \`canon.character_visual_assets\` and \`canon.faction_visual_assets\`.
- Existing \`shared.assets\` represents world/land-investment assets; **not image/media assets**, so do not reuse that table or create a second universe/franchise registry.
- Character originals remain in private \`sideworld-character-media\` and are already referenced by the quest's immutable portrait pins. Faction originals remain in \`sideworld-faction-media\`.
- No \`canon.quest_visual_assets\` registry, quest visual generation jobs, or \`sideworld-quest-media\` Storage bucket currently exists.
- Existing Studio auth uses \`shared.user_roles\` OWNER/ADMIN and service-only RPCs, with no direct Data API table grants for canon.
- Player PR #48 (Draft at audit) bundles four approved fictional images as server-only files, protected by current-actor/run/release/sequence gates. This is a pilot delivery mechanism, **not a scalable media store**.
- Existing production release \`5494ff13-3791-429d-9b8a-cdb7e2e818a9\`: Novi Sad revision 2, private QA, 7 scenes, 5 visual briefs, 4 pinned approved portrait refs; editorial approval, field verification and media clearance remain false.

## Proposed data model

**One private Storage bucket**, \`sideworld-quest-media\`, with no browser-facing Storage policies. Three additive canon-owned tables:

1. \`canon.quest_visual_jobs\` — generation/manual candidate reservations, actor/request-key idempotency, one running job per brief revision, actor-level daily caps, provider/model and spending metadata.
2. \`canon.quest_visual_assets\` — immutable source SHA and content-addressed private path, role, data provenance, rights, review state, version, dimension and MIME. References the exact existing quest draft and immutable revision. Approved canonical character portrait bytes are **not copied** here.
3. \`canon.quest_visual_bindings\` — write-once association from an existing immutable release + scene + visual role to one approved asset. Reuse a single file across multiple steps without changing shared Player code.

Scoped service-role RPCs prepare reservations, read metadata, record approval/rejection and bind approved media to the existing release. Each verifies existing Studio OWNER/ADMIN roles. The browser never receives private bucket paths or privileged credentials.

The migration is **not** an activated system: no browser Storage policies, no job-completion RPC or raw candidate-file uploader is included until server-side SHA and actual-byte readback are verified. Existing Studio Visual Production PR exposes only local candidate review and provider abstraction, with AI spending OFF by default.

## Required remaining implementation after schema approval

- Trusted Studio Storage upload + readback with SHA-256, format sniffing, 10 MiB cap, no upsert, cleanup on failed registration.
- Service-role-only completion RPC that validates the reserved job and inserts a candidate asset in the same logical flow. Failed jobs must be explicitly closed; never blindly retry a charged provider call with a new key.
- Guarded Studio REST endpoints for generation, upload, review, selection and immutable binding; response includes only safe metadata.
- Display persisted candidate gallery/history/cost from the read RPC, not browser session state.
- Update existing Player art source adapter to read private Storage by **authorized current actor, version and scene** with exact hash verification. No new renderer, universe table or game logic changes.

## Risk and deployment policy

This crosses Storage security, RLS and canonical data, so it is a **high-risk database change** and optional staging / isolated restore dry-run is justified. This does not reinstate staging as a universal requirement.

Before applying to production:
1. Confirm current migration head, live schema, auth grants, service-role privileges and preexisting Storage policies again.
2. Verify production backup availability and demonstrate restore readiness with an isolated restore test.
3. Run an isolated nonproduction SQL check for syntax, FK/enum compatibility, grants, RLS and repeated read calls.
4. Run adversarial tests: non-admin denied, service role limited, foreign draft/release denied, guessed future scene denied, duplicate request key no double charge, 24-hour rate caps, malformed/oversized images rejected, wrong SHA denied, media not publicly accessible.
5. Require explicit founder authorization for execution, and then observe logs before activating any write flags or paid image provider.

## Rollback (only with confirmed absence of persisted user content)

Reverse in dependency order:
- Revoke/remove \`sideworld_quest_visual_bind\`, \`sideworld_quest_visual_review\`, \`sideworld_quest_visual_inventory\`, \`sideworld_quest_visual_reserve\`.
- Drop \`canon.quest_visual_bindings\`, \`canon.quest_visual_assets\`, \`canon.quest_visual_jobs\` **only after checking they are empty and documenting any generated/published assets**.
- Remove \`sideworld-quest-media\` bucket only when it is empty; never delete media bytes automatically.
- If content exists, use forward-fix migrations, not destructive rollback. No preexisting quest/character/universe rows are touched by this migration.

**No production migration was applied, and no bucket was created during this PR.**
