# SIDEWORLD Player Runtime V1 — production deployment evidence

**Recorded:** 2026-10-14. **Status:** Production migration APPLIED and independently verified via read-only SQL. This is a database-schema milestone only; **SIDEWORLD gameplay, private QA releases and tester grants remain inactive**.

## Change identity

| Field | Verified |
| --- | --- |
| OUTLAND production Supabase project | `huzcukdovavejejwohey` |
| Staging Supabase project | `clgpxvyflycudzhdzjlv` |
| Migration version/name | `20261014104136` / `sideworld_player_runtime_v1` |
| Source file | `supabase/migrations/20261014104136_sideworld_player_runtime_v1.sql` |
| Original SQL Git blob SHA | `8fcca2a8a0eec82f4dd899412e14848d279b9295` |
| Source SHA-256 (preapproved) | `8b12b3869d1d693d0d826b3fc40c19a837e58ad69c06a2379ed6c687eb9baeb2` |
| SQL recorded in production migration ledger | 1 statement, 21415 UTF-8 bytes, MD5 `6c6e1316567539d03e70ea5688ffca6b` |
| SQL recorded in staging migration ledger | Identical version/name, bytes and SQL MD5 |
| Production ledger count after deployment | 39 |
| GitHub CI for approved SQL and atomic runner | Database CI [#38558777175](https://github.com/outland-compass/outland/actions/runs/38558777175) PASS (5 jobs); Web CI [#38558777165](https://github.com/outland-compass/outland/actions/runs/38558777165) PASS |
| Backup and isolated restore | Studio encrypted read-only export + application-table isolated restore [#38550055892](https://github.com/outland-compass/sideworld_studio/actions/runs/38550055892) PASS; founder attested encrypted backup stored externally and decryption key separately |

## Authorized change execution and read-only postflight

Founder explicitly authorized the **specific production SQL only**, with gameplay OFF. The migration was executed once using the reviewed atomic PostgreSQL transaction renderer, including an advisory lock, preflight checks, the unchanged migration SQL, an atomic insert into `supabase_migrations.schema_migrations` preserving version `20261014104136`, RLS/RPC postflight asserts and commit.

**Independent read-only verification AFTER the execution** confirmed:

- Exactly **one** migration ledger row with the pinned version and name; total migration count **39**. Production and staging stored exactly the **same SQL MD5 and byte length**.
- New tables present: `canon.quest_releases`, `player.qa_access`, `player.quest_runs`, `player.run_receipts`.
- Each table has row-level security enabled, **zero** permissive client policies and no direct `anon`/`authenticated` DML/SELECT privilege.
- All **eight** new `public.sideworld_player_*` RPCs exist, are `SECURITY DEFINER` with empty `search_path`, are executable by `service_role`, and **not executable** by `anon` or `authenticated`.
- **Zero** rows in all four new tables: no QA releases, grants, player runs or idempotency receipts were created.
- All four new tables appear in the Supabase Security Advisor under `rls_enabled_no_policy` **INFO**. This is intentional private deny-by-default. Existing unrelated Auth/function warnings were not modified.
- No production migration was repeated during later verification. Neither existing historical migration versions nor canonical universe structures were rewritten.

## Git and deployments: separate lifecycle

At initial postflight, the reviewed OUTLAND [PR #70](https://github.com/outland-compass/outland/pull/70) remained **OPEN DRAFT** at head `ba15306ddfdf9004a6ae8e30e419bc37b982020d`, although the exact SQL had already been applied. Source-control merge/deploy reconciliation is **separate from SQL execution**; merging this PR must **never run production DDL a second time**.

Read-only deployment check: Vercel `outland` and `outland-world-v0` already had successful PR-head preview builds; the latest SIDEWORLD Studio production deployment still pointed to pre-QA-UI commit `bcb67fc...`, while Player had no newly verified production rollout. A green database schema is **not** an operationally enabled Player.

## Do not reactivate one-time migration commands

The `player-runtime-preflight.mjs --db-preflight` CLI and rendered atomic SQL deliberately **fail closed after a successful cutover**, because their invariants require 38 prior migrations and no Player runtime objects. Do not disable or bypass those invariants, rerun migration, run blind `supabase db push`, or alter the ledger to “repair” successful production state. The runner is preserved as an auditable, inert release artifact.

## Next authorized engineering tasks (no live QA or public gameplay)

- Reconcile and merge reviewed GitHub migration/recovery SQL and tests with production schema state, using green GitHub PR + CI. Review any Vercel production build triggers before merge, and preserve current gameplay OFF.
- Build/live-test the **separate** Studio-authenticated private operator workflow, canonical Player content-hash handshake, revocable QA grants, durable operator audit and distributed rate limits behind explicit default-OFF flags. No browser-controlled service-role privileges.
- Review ordinary player login and hidden-answer projection end to end. No real tester invitations, releases, content publication or Player environment unlock without separate founder approval.
- Verify encrypted backup custody, key separation and recovery boundary: prior GitHub test proved application-table restore, **not complete managed Supabase Auth/Storage disaster recovery**.

**Boundary:** This record documents a completed, specifically authorized schema application. It does not authorize enabling SIDEWORLD gameplay, deploying new Player/Studio routes, creating real user sessions or publishing content.
