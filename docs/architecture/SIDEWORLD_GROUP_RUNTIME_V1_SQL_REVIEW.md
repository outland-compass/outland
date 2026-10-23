# SIDEWORLD Group Runtime V1 — Review and execution plan

Status: **SQL proposal only. Not a Supabase migration and not executed anywhere.**

Proposal: [`SIDEWORLD_GROUP_RUNTIME_V1_SQL_PROPOSAL.sql`](./SIDEWORLD_GROUP_RUNTIME_V1_SQL_PROPOSAL.sql).

## Grounded against current production

Production Supabase `huzcukdovavejejwohey` was inspected read-only before this proposal. `player.quest_runs`, `player.run_receipts`, `canon.quest_releases`, `player.qa_access`, `player.private_access` and existing service-role-only Player RPCs are present. There are no live `player.group_sessions`, `group_members`, `group_receipts` tables or `public.sideworld_group_*` RPCs at the time of inspection.

OUTLAND migrations `20261014104136`, `20261014220543`, `20261016151956` were read before authoring this SQL. The proposal is **additive only**; the canonical universe and existing Solo runtime remain untouched.

## Exact existing Player consumer

Already-checked-in, server-only code:
- `sideworld_app/lib/gameplay/group-supabase-adapter.ts` expects six `sideworld_group_*_v1` RPCs with service-only invocation: `create`, `join`, `get`, `receipt_get`, `apply`, `leave`.
- `sideworld_app/lib/gameplay/group-read.ts` requires only an actor-authorized role projection.
- `sideworld_app/lib/gameplay/group-actions.ts` trusts existing deterministic Player engine, not browser-derived progress.
- `sideworld_app/lib/gameplay/group-http.ts` is **not routed** and is additionally gated on three disabled environment approvals.

The new `group-coordination.ts` introduced in Player #114 overlaps with an older read/action/adapter stack. **Do not wire both runtimes.** Reconcile/remove the redundant abstraction in a separate low-risk Player PR before activating HTTP.

## SQL proposal contents

- Three new `player` tables with RLS enabled and zero direct anonymous/authenticated/service-role grants.
- A single immutable release pin and shared `progress` per session; role/member identity separately constrained.
- A hash-only short-lived invite, actor-specific access checked using `player.can_use_release_v1` on every action.
- Atomic row-locked `join`, and `sequence + progress + receipt + terminal status` inside a single database transaction.
- Service-role-only `SECURITY DEFINER` RPC with an empty `search_path`; explicit PUBLIC and browser-role revocation.
- No persistent chat/guild/team identity, no new universe tables, no permission changes to canonical models.

## Hard gates before promotion to a real migration

1. **SQL review:** PostgreSQL parser/test execution still required. This proposal has NOT been SQL compiled, transaction-tested, or validated by Supabase migration tooling.
2. **CLI migration:** run `supabase migration new sideworld_group_runtime_v1` in OUTLAND, place reviewed SQL in the CLI-created file, and commit it as a separate migration PR. The current runtime does not have a usable Supabase CLI.
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
- **Not implemented:** any production DDL, active group endpoint, real multi-device play, or synchronized UX.
