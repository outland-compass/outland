# SIDEWORLD Quest Visual Production — Applied Additive DB V1

**Status: APPLIED to production 2026-10-15 with explicit founder authorization.** Supabase recorded migration version `20261015210824`. Existing Player and quest data were preserved. **Paid AI image generation and Player registered-media flag remain disabled.**
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

The migration is **not an activated system**. It now includes service-only job completion/failure RPCs, SHA/version-scoped inventory, approval/binding and a release-visual read RPC. Companion Studio PR #50 includes gated upload/readback and private gallery endpoints. These components are now installed in the live database, with no browser Storage policies. Studio manual writes are enabled for production. OpenAI paid generation and Player registered-media flag remain OFF.

## Production execution and verification (15 Oct 2026)

- Applied the *exact reviewed SQL bytes* from this migration via the Supabase migration API, after explicit founder approval. The API assigned version `20261015210824`; this repository file was renamed to match that installed version so future migration replays do not attempt a duplicate apply.
- Fresh read-only production backup and isolated restored application fingerprints passed: Studio Actions backup/restore run `38644178274`, attempt 2. Encrypted artifact is retained through 22 Oct 2026. **Backup covers application database data, not all Supabase Storage objects and settings.**
- Post-migration SQL verification: private `sideworld-quest-media` bucket exists with 10 MiB limit and PNG/JPEG/WebP allowlist; all three new canon tables have RLS ON and zero browser-facing policies; all eight `sideworld_quest_visual_*` RPCs deny `anon` and `authenticated`, allow `service_role`.
- Existing Storage object policies cover only `compass-evidence`; none grants browser access to the new bucket.
- Initial media inventory: zero new images, zero jobs, zero scene bindings. No user or quest records migrated/deleted.
- Studio Vercel production `SIDEWORLD_QUEST_VISUAL_WRITES=enabled`, `SIDEWORLD_VISUAL_AI_ENABLED=disabled`; deployment verified READY. Player `PLAYER_QUEST_MEDIA_STORAGE_ENABLED` remains absent/OFF, retaining the existing bundled Novi Sad art and private run/sequence gate.
- **Not yet exercised:** authenticated founder upload and approve through real Studio UI, end-to-end Player retrieval from newly bound Storage, provider account billing. These must not be represented as completed tests.

## Remaining release/QA work

- Validate manual WebP candidate upload, persistent gallery, explicit approval and binding using an existing admin Studio login (no special QA player or time-limited access).
- After an asset is successfully bound and the existing Player actor-run/release/sequence checks are verified, separately enable registered Storage media in Player. Do not make the images public by URL.
- Paid image generation remains OFF and requires separate provider access/spending authorization; do not silently switch it on.
- Maintain audit trail and versioned data-only art; retain paths on ambiguous commit/network failures rather than deleting a possibly registered original.

## Risk and deployment policy

This crosses Storage security, RLS and canonical data, so it is a **high-risk database change** and optional staging / isolated restore dry-run is justified. This does not reinstate staging as a universal requirement.

Verified approval checklist / required before any future high-risk migration:
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

**Production migration successfully applied. No AI provider calls or quest/publication changes were performed.**
