# Puzzle Option Media V1 — rollout and rollback

## Scope
Canonical project: OUTLAND Supabase `huzcukdovavejejwohey`. The single additive migration creates `canon.quest_puzzle_option_media` and two service-role-only RPCs. Existing quest releases, quest media, worlds, OUTLAND functionality and legacy bindings are left untouched.

## Deployment sequence (do not skip)
1. Review OUTLAND migration PR, Studio PR and Player PR. Require passing CI and verify both applications still serve the last pinned production revision.
2. Confirm production DB backup exists and demonstrate a successful isolated restore (especially important on Supabase free tiers; do not treat available backups as guaranteed).
3. Apply the migration to the retained staging environment and run scoped read/bind tests with valid actor, wrong actor, wrong release, unapproved asset, mismatched revision, duplicate option, and published release; verify `anon` and `authenticated` have no direct table access or RPC execute permission.
4. Obtain **separate explicit production database migration approval**. Migrate production, verify `pg_policies`, function ACLs, indexes, existing row counts, and unchanged release content hash.
5. Deploy Studio and Player with `SIDEWORLD_QUEST_VISUAL_WRITES=enabled` (existing Studio flag) and opt in Player via `PLAYER_PUZZLE_OPTION_MEDIA_ENABLED=enabled` only after the migration.
6. Upload four P5 WebP sources as candidates; compare exact OCR-visible dates and images; explicitly approve and bind all four option IDs. Use local handoff ZIP, not binary SQL. Verify a private actor-owned playthrough and a non-owner denial. No public publication is implicit.

## Rollback
- First disable `PLAYER_PUZZLE_OPTION_MEDIA_ENABLED` and return Player to text-only cards; keep all asset originals.
- Revert Studio/Player PRs if needed. The canonical table and bindings are harmless, private and additive.
- **Do not drop the table if it has rows**; preserve the audit and image mappings. To remove an unused migration, verify an empty table in a maintenance window, drop the two v1 RPCs, then the table. No automatic destructive rollback.
- Never delete binary originals to roll back a UI change.

## Invariants
- Quest `document`, `engine_content_hash`, draft revision, answers, and other bindings are not edited by media registration.
- At most one approved image per option, no overwrite, current-step-only Player delivery, SHA-256 verification before serving.
- No `service_role` credentials or storage paths in the Player/browser.
- Studio records existing `quest_visual_jobs`, `quest_visual_assets` and `sideworld_quest_visual_review` approval audit before binding.
