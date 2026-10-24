# SIDEWORLD Group Runtime V1 — Review and execution plan

Status: **CLI-generated migration under review, tested in disposable PostgreSQL; production database remains unchanged.**

Migration: [20261024040523_sideworld_group_runtime_v1.sql](../../supabase/migrations/20261024040523_sideworld_group_runtime_v1.sql).

Proposal: [`SIDEWORLD_GROUP_RUNTIME_V1_SQL_PROPOSAL.sql`](./SIDEWORLD_GROUP_RUNTIME_V1_SQL_PROPOSAL.sql).

## Grounded against current production

Production Supabase `huzcukdovavejejwohey` was inspected read-only before this proposal. `player.quest_runs`, `player.run_receipts`, `canon.quest_releases`, `player.qa_access`, `player.private_access` and existing service-role-only Player RPCs are present. There are no live `player.group_sessions`, `group_members`, `group_receipts` tables or `public.sideworld_group_*` RPCs at the time of inspection.

OUTLAND migrations `20261014104136`, `20261014220543`, `20261016151956` were read before authoring this SQL. The proposal is **additive only**; the canonical universe and existing Solo runtime remain untouched.

## Exact existing Player consumer

Already-checked-in, server-only code:
- `sideworld_app/lib/gameplay/group-supabase-adapter.ts` expects six `sideworld_group_*_v1` RPCs with service-only invocation: `create`, `join`, `get`, `receipt_get`, `apply`, `leave`.
- `sideworld_app/lib/gameplay/group-read.ts` requires only an actor-authorized role projection.
- `sideworld_app/lib/gameplay/group-actions.ts` trusts existing deterministic Player engine, not browser-derived progress.
- `sideworld_app/lib/gameplay/group-http.ts` is **routed but disabled** by combined private and Group server-only approval gates.

The unused duplicate coordinator was removed in Player PR #115; the single supported Group HTTP route was merged in PR #116 and deployed with feature flags OFF.

## SQL proposal contents

- Three new `player` tables with RLS enabled and zero direct anonymous/authenticated/service-role grants.
- A single immutable release pin and shared `progress` per session; role/member identity separately constrained.
- A hash-only short-lived invite, actor-specific access checked using `player.can_use_release_v1` on every action.
- Atomic row-locked `join`, and `sequence + progress + receipt + terminal status` inside a single database transaction.
- Service-role-only `SECURITY DEFINER` RPC with an empty `search_path`; explicit PUBLIC and browser-role revocation.
- No persistent chat/guild/team identity, no new universe tables, no permission changes to canonical models.

## Hard gates before applying the migration to production

1. **SQL review:** Real migration replay, transaction tests, grant checks and separate-session concurrency passed in GitHub Actions; verify the final PR SHA after any further changes.
2. **CLI migration:** created using Supabase CLI v2.119.0 on GitHub Actions, checked into OUTLAND PR #87. The migration has NOT been applied remotely.
3. **Backup:** verify a recent production backup and an isolated successful restore. SQL is auth/RLS-sensitive: staging rehearsal is justified.
4. **Privileges:** prove `anon`, `authenticated`, `PUBLIC` have no schema/table/function route; prove only `service_role` may invoke the new RPCs. Auth identity must be verified in Next.js; SQL `p_actor` is a trusted parameter only behind that boundary.
5. **Concurrent tests:** two simultaneous joins for final role; two conflicting same-sequence actions; duplicate request replay; revoked entitlement; expired invite; member leaving; member/role spoofing; role clue privacy; hash-version mismatch.
6. **Content:** a new immutable quest release with `experienceModes` for Couple is required. Existing Solo releases must not be rewritten.
7. **Activation:** even after separately approved production DDL, Player HTTP and all three environment gates remain OFF until separately accepted.

## Non-destructive rollback

- **First:** disable unlaunched/flagged group routes; revoke EXECUTE on the six new RPCs if a security issue occurs.
- Keep `group_sessions`, `group_members`, and `group_receipts` records for forensic analysis; do not drop or truncate user progress.
- Apply additive corrective migrations instead of rewriting old ones; never modify Solo RPCs/releases.
- Preserve the optional staging environment as a targeted auth/data migration test tool.

## Decision status

- **Approved:** production-first policy, GitHub PR + CI, additive schemas, no duplicate universe, no production DB writes without explicit authorization.
- **Proposal requiring review:** exact table/RPC layout, 30-minute invitation TTL, 32 retained receipts, abandonment on departure.
- **Not implemented:** production DDL, an enabled Group endpoint, a reviewed Couple release, real multi-device QA, or synchronized UX.
