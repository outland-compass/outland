# SIDEWORLD R17 same-revision editing — migration approval package

Status: **PROPOSED, NOT AUTHORIZED FOR PRODUCTION** (15 November 2026).

## Why
The existing `public.sideworld_quest_draft_save` increments `canon.quest_drafts.revision`
for every ordinary Save and inserts into `canon.quest_draft_revisions`.
This is a software policy, not a database necessity. The founder explicitly
rejects new quest revisions without separate consultation. Existing R16
private release remains untouched.

## Read-only production evidence (2026-11-15)
- Draft `d53c11cf-e5ea-4f36-a1b8-5301a20dfb1e`: current revision **17**.
- No `canon.quest_releases`, `canon.quest_visual_assets` or
  `canon.quest_visual_jobs` referencing that draft **at revision 17**.
- Older releases and media reference revisions R3–R16 and remain immutable.
- `canon.quest_releases` is guarded by `canon.sideworld_guard_release_v1`,
  which allows private QA content edits with same ID and hash update but
  prohibits changing source revision or publishing stale/unreviewed content.
- Direct database grants on draft tables are revoked from browser roles; existing
  authenticated Studio API uses a service-role-only, actor-scoped RPC.
- The existing source FK from releases/media to draft revisions remains intact.

## Proposed additive change
Migration:
`supabase/migrations/20261115213318_20261115220000_sideworld_r17_in_place_editorial_save_v1.sql`.

1. Add `canon.quest_draft_edit_history` with immutable **previous-document
   checkpoints** and author attribution; RLS enabled and no direct role grants.
2. Add service-role-only `sideworld_quest_draft_save_current_r17_v1`.
3. Only the exact named Novi Sad draft at revision 17 is accepted. Other drafts,
   versions, releases and historical revisions are left untouched.
4. Require OWNER/ADMIN actor, JSON contract/scope validation, an active draft,
   an exact JSONB compare-and-swap under row locks, and **zero R17 release,
   media or job dependencies**. The Studio API additionally validates
   puzzle/narrative, visual timeline and private-image entitlements.
5. Atomically record the prior document + diagnostics, update the existing
   R17 row, and return **revision 17**. No automatic asset carry-forward or
   new release. If anything fails, SQL transaction rolls back.
6. Studio endpoint remains disabled unless
   `SIDEWORLD_R17_IN_PLACE_SAVE_ENABLED=enabled` is activated separately.
   Old `action:'save'` on this R17 draft is rejected to prevent R18.

## Activation checklist — do NOT execute until explicit founder authorization
- [ ] Verify a fresh, usable production backup **and an isolated restore rehearsal**.
- [ ] Match live production schema, R17 document hash, source dependencies,
      migration ledger and executing role to the reviewed snapshot.
- [ ] Pass OUTLAND migration SQL CI and Studio API/UX test CI.
- [ ] Apply **only** the named migration to the intended Supabase project,
      after specific approval for this exact SQL.
- [ ] Verify new RLS and EXECUTE ACLs deny anon/authenticated, service_role only.
- [ ] Use authenticated founder session to save a controlled, non-story-changing
      R17 field; confirm same revision, history checkpoint, CAS conflict handling,
      unchanged R16 release, and read-after-write consistency.
- [ ] Only then enable `SIDEWORLD_R17_IN_PLACE_SAVE_ENABLED` on the Studio
      Vercel production project; deploy a pinned CI-green main commit.
- [ ] Verify full 9-page import, source R9 image pair, unresolved page 6/8/9
      image warnings, save/reload, and that Player release remains blocked.

## Failure / rollback
Disable the Vercel flag first. Optionally revoke EXECUTE for service_role.
Keep the `quest_draft_edit_history` audit table **and its data**. Previous
R17 document can be recovered from an audited checkpoint using a separate
authorized, transactionally guarded restore procedure. Never delete older
quest snapshots, existing image registry rows, R16 releases or OUTLAND data.
There is no automatic production rollback of edited quest content.

## Explicit non-goals
No new R18, no Player or public release, no automatic image approval,
no copying 35 image references, no puzzle answer change, no RLS weakening,
no global switch to editing arbitrary released revisions.
