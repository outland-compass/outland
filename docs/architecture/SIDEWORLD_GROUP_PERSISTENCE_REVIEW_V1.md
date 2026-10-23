# SIDEWORLD Group Session Persistence — Review Package V1

**State:** DESIGN AND SQL DRAFT ONLY. No Supabase migration, no staging or production execution, no public API activation.

## Files

- `sql-drafts/sideworld_group_sessions_schema_v1.sql`: additive tables, keys, data-size constraints, indexes, RLS enabled and no direct client permissions.
- `sql-drafts/sideworld_group_rpcs_v1.sql`: service-role-only RPC proposal for group create, join, read, receipt lookup, apply/CAS, and leave.

## Verified baseline

Production Supabase was inspected read-only on October 23, 2026. It already has immutable `canon.quest_releases`, actor-owned `player.quest_runs`, `player.run_receipts`, and `player.can_use_release_v1`. Existing Solo run RPCs are `SECURITY DEFINER` with empty search path and service-role-only execution. The proposed group tables do not exist. Existing RLS and privileged access flow are left untouched.

Canonical universe and world registry remains unchanged.

## Authoritative boundaries

**HTTP layer**: verify authenticated actor from the session, never JSON; reject cross-origin calls and bound request bytes; generate cryptographically random 32-byte join token and hash server-side; keep all service credentials and full release documents server-only. Group features remain OFF.

**Database layer**: check *current* entitlement via `player.can_use_release_v1` for create, join, read and apply; lock session row during joins/actions; pin immutable release hash; allocate member roles from validated authored release, not client input; atomically update progress and action receipt; permit exact retry on completed session. No direct grants to `anon` or `authenticated`.

**Game engine**: only existing deterministic Player computes `nextProgress` and `isTerminal`; the database checks its metadata/sequence but does not independently replay puzzles. See Player [#108](https://github.com/outland-compass/sideworld_app/pull/108) and [#109](https://github.com/outland-compass/sideworld_app/pull/109).

## Mandatory unfinished work

1. Independently review the draft SQL and confirm exact existing migrations/functions once more.
2. Run `supabase migration new sideworld_group_sessions_v1` using an installed, version-checked Supabase CLI. The execution environment used for this design has no installed CLI and cannot fetch npm packages; **do not invent a numbered migration filename**. Move the reviewed SQL into that proper migration.
3. Apply to *existing staging only after the user approves that staged DB modification*. Run real concurrent connections and direct/REST privilege checks.
4. Verify backup availability and **successful restore rehearsal** for production data. Backup readiness has not yet been established.
5. Check Supabase security advisors and privilege diffs; no new `PUBLIC` or `authenticated` execute permissions.
6. Confirm that token hashing/expiry, role count, terminal receipt, and replay rules match the actual Player adapter contract; fix anything exposed by staging tests.
7. Request **separate, explicit founder approval** for the exact production migration and feature enablement. Do not infer approval from general instructions to continue autonomously.
8. After an approved production DDL, keep private group routes behind an OFF-by-default feature flag until browser/two-phone field QA passes.

## Test matrix before activating multiplayer

| Surface | Negative/adversarial test | Expected |
|---|---|---|
| REST authorization | anonymous/authenticated calls to new RPCs | permission denied |
| Identity | client sends different actor ID | ignored/rejected in Next.js |
| Release access | expired/revoked QA or private grant | denial on each operation |
| Membership | other actor reads/edits same group ID | denial |
| Invite | invalid/expired/reused token | denied for new member |
| Parallel join | 3 actors race for last slot | exactly one joins |
| Parallel apply | 2 players act on same sequence | exactly one commits |
| Retry | same request ID and fingerprint | same result, no duplicate advance |
| Replay abuse | different fingerprint/actor with same request ID | conflict |
| Terminal | exact final-action retry after completion | original receipt; no new action |
| Secrets | role clue from other member or future puzzle | never in client JSON |
| Compatibility | legacy Solo run and hash | unchanged |
| Isolation | new franchise or universe | no hard-coded player branch |

## Recovery

- Kill switch: disable group routes without altering legacy Solo endpoints or stored runs.
- In-flight group state and receipts are retained for incident analysis; do not DROP tables as an emergency rollback.
- If a migration must be corrected, use another backward-compatible migration, never replay an applied baseline.
- The database schema draft is not a deployment artifact and must not be applied directly.
