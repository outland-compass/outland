# SIDEWORLD — Group Runtime V1 Live Schema Compatibility Audit

**Date:** 2026-10-24 (read-only inspection). **Environment:** Supabase production `huzcukdovavejejwohey`. **No database writes.**

**Proposed migration:** `supabase/migrations/20261024040523_sideworld_group_runtime_v1.sql`, merged into OUTLAND `main` in PR #87. **Status:** present in GitHub only; remote production has **not** applied it.

## Confirmed live database state

Read-only catalog, table and migration queries were executed through the connected Supabase project, not inferred from GitHub alone.

- PostgreSQL version `17.6`.
- Latest applied production migration: `20261019063001_sideworld_location_reference_media_v1`.
- Canonical `canon.quest_releases` exists with `id uuid`, `source_draft_id uuid`, `source_revision integer`, `document jsonb`, `engine_content_hash text`, `visibility text`. Its FK `(source_draft_id,source_revision)` references `canon.quest_draft_revisions`.
- `auth.users` exists and existing `player.quest_runs` rows use an `auth.users(id)` actor FK and `canon.quest_releases(id)` release FK.
- `player.qa_access` and `player.private_access` exist with `release_id uuid`, `actor_id uuid`, current expiry/revocation fields and RLS enabled.
- `player.can_use_release_v1(uuid,uuid)` exists and checks: fully authorized `published` releases, `private_qa` grants not expired/revoked, or `private` owner/admin or private grants. It is `SECURITY DEFINER` with an empty search path.
- `player.group_sessions`, `player.group_members` and `player.group_receipts` are all **absent**; six `public.sideworld_group_*_v1` functions are **absent**.
- No second universe registry, release mutation or Solo table rewrite is present in the proposed Group SQL.

## Source-to-live compatibility checks

| Proposed dependency | Live check | Result |
| --- | --- | --- |
| `canon.quest_releases(id)` | UUID PK and existing release row shape | **Compatible** |
| `canon.quest_releases(source_draft_id,source_revision,document,engine_content_hash,visibility)` | Named columns with expected PostgreSQL types | **Compatible** |
| `auth.users(id)` | Existing FKs already reference it | **Compatible** |
| `player.can_use_release_v1(uuid,uuid)` | Exact live function exists; valid visibility contract | **Compatible** |
| New `player.group_*` names | No conflicting live relations | **Available** |
| Six new `public.sideworld_group_*_v1` names | No existing functions with these names | **Available** |
| Proposed DDL & SQL transaction behavior | GitHub disposable PostgreSQL migration replay, privilege + concurrency tests passed in PR #87 | **CI-confirmed, not live-executed** |
| Current production backup recoverability | Neither protected live logical export nor isolated restore evidence observed | **BLOCKED** |

**Note on function grants:** `player.can_use_release_v1` itself is not directly executable by `service_role` in the current catalog. The proposed Group RPCs are `SECURITY DEFINER` and invoke it in their owner context. Disposable SQL CI passed, but repeat owner/grant verification against an **isolated restore** before production DDL. This check is not authorization to grant public EXECUTE.

## Verified quest publication state

- Novi Sad pilot draft revision **9** contains seven scenes and no `experienceModes`. The existing corresponding immutable release is `visibility='private'` and **not a Couple release**.
- Studio's guarded QA release workflow creates `private` release visibility, not `private_qa`. The Player follow-up fix in PR #118 defaults Group creation to `private` while retaining explicitly supported `private_qa` use cases.
- A new, reviewed, hash-aligned, **saved draft revision** with distinct Observer/Decoder private clues and an entirely **new immutable private release** must be produced before a valid Couple session exists.

## Required go/no-go before any production DDL

1. Repeat current schema and migration audit against the exact remote project immediately before execution.
2. Produce a **protected production backup** (roles, schema, data and storage-object inventory) on a trusted local workstation; don't put dumps in GitHub artifacts or chat.
3. Restore it into an **isolated Postgres 17 / Supabase-compatible environment**. Verify migration ledger, counts and relevant release hash/access-control parity, including extension compatibility.
4. Run the additive Group migration only in that restored copy. Repeat RLS, function grant, mixed actor, invite TTL, concurrent CAS/idempotency and Solo regression tests.
5. Preserve compatibility via feature flags default OFF; use corrective additive migrations rather than destructive rollback.
6. Obtain separate explicit founder authorization before **production migration** and **multiplayer feature activation**. PR merge alone authorizes neither.

**Decision:** No live schema mismatch was found that would require rewriting the proposed Group migration. The **restore-readiness gate is unverified**. No production SQL was executed as part of this audit.
