# SIDEWORLD Multiplayer Session Layer V1 — OUTLAND Database Design Proposal

**Status:** Design PR only. **Not an applied migration.**
**Date:** 2026-10-23
**Dependencies:** Player [PR #107](https://github.com/outland-compass/sideworld_app/pull/107), Studio [PR #103](https://github.com/outland-compass/sideworld_studio/pull/103).
**Owner:** OUTLAND Supabase migration repository; NOT Studio or Player.
**Production authorization:** A separate, explicit approval is required before any production DDL.

## 1. Verified production and code baseline

Read-only inspection on 2026-10-23:
- Production project `huzcukdovavejejwohey`, PostgreSQL 17, healthy.
- Existing `canon.quest_releases` is an immutable, versioned snapshot with a JSONB `document` and `engine_content_hash`.
- Existing `player.quest_runs` is actor-owned (`actor_id`), uses `sequence` and bounded `progress`.
- Existing `player.run_receipts` stores idempotency records.
- Existing `public.sideworld_player_run_start_v1`, `run_get_v1`, `run_apply_v2` are `SECURITY DEFINER`, owned by `postgres`, explicitly `service_role` EXECUTE-only with `search_path=''`.
- Existing `player.can_use_release_v1` is the authoritative per-actor entitlement predicate; QA and private release grants may be revoked.
- Existing `player` tables have RLS enabled and deliberately zero direct `anon`/`authenticated` policies or table grants.
- Reviewed migration sources include 20261014104136, 20261014150000, 20261014220543, and 20261016151956.

Do not change existing run RPC signatures, actor-owned progress data, release immutability, universe registry or `shared.worlds`.

## 2. Minimal additive tables (PROPOSED; NOT SQL ready for deployment)

**`player.group_sessions`**
- `id uuid primary key`; `release_id uuid` references `canon.quest_releases(id)` with restrict; `host_actor_id uuid` references `auth.users(id)`.
- `mode text` checked `('couple','team')`, `status text` checked `('forming','in_progress','completed','abandoned')`.
- `engine_content_hash text` (64-hex), `engine_version integer`, `expected_size smallint` (couple=2, team=3 or 4).
- `progress jsonb` private, size bounded; `sequence integer` nonnegative and consistent with trusted engine progress.
- `invite_token_hash text` (no plaintext token), `invite_expires_at timestamptz`, `created_at`, `updated_at`.
- No public or direct user role grants; RLS defense in depth. A server-only service-role RPC is the only mutation route.

**`player.group_members`**
- `session_id uuid` references group session, `actor_id uuid` references `auth.users`, `role_id text`, `joined_at`, optional `left_at`.
- Unique active membership for `(session_id,actor_id)`; unique active `(session_id,role_id)` prevents two members receiving the same role.
- Explicit authorization remains **per actor**, not implied by link possession or another member's entitlement.

**`player.group_receipts`**
- `session_id`, `request_id uuid`, `actor_id`, `fingerprint text`, `result_sequence`, and bounded private `result_progress jsonb`.
- Unique `(session_id,request_id)`; repeated identical commands return their committed result; conflicting request reuse fails.
- Receipt retention bounded similarly to existing `run_receipts`; never expire a receipt so early that retries could apply twice.

**No `groups`, `guilds`, persistent relationship model, leaderboard, chat history or separate Couple tables in V1.**
A lightweight metadata-only `group_events` table can be added later if needed for durable diagnostics.

## 3. Group RPC candidates (new signatures; unchanged Solo RPCs)

- `sideworld_group_create_v1(actor, release, mode, request_id, initial_progress, invite_hash, expiry)`
- `sideworld_group_join_v1(actor, session, invite_proof, request_id)`
- `sideworld_group_get_v1(actor, session)`
- `sideworld_group_apply_v1(actor, session, request_id, fingerprint, expected_sequence, next_progress, is_terminal)`
- `sideworld_group_leave_v1(actor, session, request_id)`

These are candidate boundaries, **not finalized signatures**. The server must derive the actor from a verified session and validate a real source release; do not trust client `actor`, `role`, progress, or answers.

Do not expose `canon.quest_releases.document` or `player.group_sessions.progress` in public responses.
Only the trusted Player server may call the RPCs using a server-only credential.

## 4. Non-negotiable transaction and access invariants

1. The Player HTTP boundary independently verifies the JWT and obtains the actor ID; do not accept a browser-provided actor ID.
2. Each create/join/get/apply checks **the current** `player.can_use_release_v1(actor, release)`, including expiry/revocation.
3. On every action, lock the session row. Check exact release ID, immutable content hash, engine version, valid active membership, role allocation, status, and `expected_sequence` before writing.
4. Trusted Player runtime computes and validates the next progress and terminal state. The database checks pins/size/sequence, but cannot independently infer gameplay transitions.
5. The session `sequence`, next `progress`, terminal flag and idempotency receipt commit in ONE transaction.
6. Invitation token is generated with sufficient entropy, transmitted only to authorized app clients, hashed using a server-side scheme, time-limited, request-limited, and never a replacement for authenticated member authorization.
7. Membership role assignment is atomic and drawn only from validated `experienceModes` of the pinned release. No client-chosen privileged role.
8. Cross-actor/cross-session data requests fail closed. After a grant is revoked, a member cannot read new state or actions.
9. Role-specific clues are projected **after** authorization for the exact current puzzle step. No raw `experienceModes`, future role clues, private answer keys or unearned Notebook items in client JSON.
10. Session behavior under disconnect, abandonment, duplicate joins, membership loss and host loss is specified before activation. V1: paused/inactive group rather than silent host takeover.

## 5. Realtime and operational cost

Start with **bounded adaptive refresh** in the feature-flagged pilot rather than a new WebSocket service or broadcasting hidden session rows:
- refresh after every local action and on focus/resume;
- during a cooperative puzzle, poll only while the view is active (e.g. around 5–10 seconds);
- during travel/navigation, slow down substantially; stop on hidden/offline tabs;
- server responses carry sequence/version and only the requesting member's authorized projection.

Measure database requests and stale conflicts in the initial 2-player field test. Consider Supabase private Realtime broadcast only when usage demonstrates the need and privacy/auth configuration has been reviewed.

## 6. Rollout and safety

- Separate low-risk code PRs from high-risk Auth/RLS/DDL.
- Create a **properly named new migration via Supabase CLI** in OUTLAND after reviewing this design and the exact current schema.
- Add RLS defense in depth, explicitly revoke table/schema privileges and default function PUBLIC EXECUTE; grant narrowly to `service_role`. Set `search_path=''` for any justified `SECURITY DEFINER` function.
- Prepare static SQL checks, isolated concurrency tests and role-spoof/revocation tests.
- Before production DDL, independently verify encrypted backup availability and a successful restore rehearsal. Use existing staging only where the security/data migration risk requires it.
- Any production DDL requires separate explicit founder authorization.
- Keep all group HTTP/UI paths OFF behind an opt-in feature flag until acceptance; code-only PR merges must not enable production group play.

## 7. Rollback and non-destructive recovery

**Immediate kill-switch:** disable group mode routes/UI, stop new session creation and revoke group RPC EXECUTE grants if an exploit is suspected.
Preserve group rows, receipts, and forensic events; do **not** drop new tables or rewrite older Solo releases as a quick rollback.
Use additive follow-up migrations for fixes. Preserve all existing Solo paths and migrations. Rollback plan must include how previously started group sessions are archived or resumed.

## 8. Acceptance tests before production activation

- Solo end-to-end, existing quest hash and regressions unchanged.
- Separate authenticated actors join the same authorized private release, exact fixed-size roles allocated once.
- Unknown/expired invite, spoofed actor, cross-session read, revoked entitlement, duplicate/reordered requests all rejected.
- Two concurrent `apply` calls cannot both advance the same `expected_sequence`.
- Idempotent replay returns identical authorized result without double advancement.
- Current-step projections reveal only the receiving member's own clue; other/future clues and answer keys never present.
- Reconnect and host departure are deterministic and privacy-preserving.
- GitHub PR + CI pass. Production DDL and activation are separate approved actions.

## 9. Next concrete steps

1. Finish Player PR #107 and Studio PR #103 CI and contract parity.
2. Verify production backup/restore readiness, role privileges, function definitions and current schema again when drafting migration.
3. Generate additive SQL via Supabase CLI; create draft OUTLAND migration PR with tests and rollback runbook. **Do not execute.**
4. Build server-only group runtime adapter in Player, plus synthetic two-actor concurrency/security tests.
5. Field QA with two phones, then 3-4 member Team support.
