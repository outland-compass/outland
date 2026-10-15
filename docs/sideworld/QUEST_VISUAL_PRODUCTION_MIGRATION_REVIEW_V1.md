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

The migration is **not an activated system**. It now includes service-only job completion/failure RPCs, SHA/version-scoped inventory, approval/binding and a release-visual read RPC. Companion Studio PR #50 includes gated upload/readback and private gallery endpoints. **None has been deployed or enabled**, and there are still no browser Storage policies. Feature flags and OpenAI paid generation stay OFF.

## Remaining activation and verification work

- Studio PR #50 implements gated Storage byte upload/readback, SHA-256, format validation, image-provider calls, durable job/asset registrations and persisted candidate gallery. **CI passed; no production writes executed.**
- Player Draft PR #49, stacked on #48, implements generic registered private media reads for the *current* actor-authorized release/scene/sequence with exact SHA verification, while preserving the Novi Sad bundle fallback. Its Storage flag remains OFF.
- Run database migration CI and isolated security/restore rehearsal; verify costs, provider access, actor-entitlement smoke and mobile illustrations; obtain separate explicit production migration approval.
- Do not turn on image spending, private Storage writes or Player registered media flags until authorized and validated.

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
- Revoke/remove all quest visual RPCs (reserve, inventory, review, bind, complete, fail, private_asset, for_release).
- Drop \`canon.quest_visual_bindings\`, \`canon.quest_visual_assets\`, \`canon.quest_visual_jobs\` **only after checking they are empty and documenting any generated/published assets**.
- Remove \`sideworld-quest-media\` bucket only when it is empty; never delete media bytes automatically.
- If content exists, use forward-fix migrations, not destructive rollback. No preexisting quest/character/universe rows are touched by this migration.

**No production migration was applied, and no bucket was created during this PR.**
