# SIDEWORLD Player — Atomic Completion Persistence V2

Status: **PROPOSED / NOT APPLIED TO PRODUCTION**. Applies after production
`20261014104136_sideworld_player_runtime_v1` and
`20261014150000_sideworld_qa_operator_audit_v1`.

## Verified baseline

On 2026-10-14, production read-only inspection found exactly one immutable
`private_qa` release for Novi Sad revision 2, one active QA grant, and one
`player.quest_runs` row with 78 event records and `status='in_progress'`.
The end-user Player screenshot showed `Adventure complete` and 7/7 puzzles.
The existing V1 SQL explicitly stores `in_progress` and does not mark
completion. This is an analytics/status gap, not proof of lost player progress.

## Change

Migration `20261014230000_sideworld_player_runtime_completion_v1.sql`
adds **one** service-role-only, `SECURITY DEFINER`, empty-search-path RPC:

`public.sideworld_player_run_apply_v2(actor,run,request,fingerprint,expected_sequence,next_progress,is_terminal)`

Trusted Player code must compute `is_terminal` from the immutable quest
engine's `view(nextProgress).step.stage === 'complete'`, never from browser
JSON, client puzzle counts, or untrusted authored document.

The new function invokes existing V1 CAS/receipt logic and changes status to
`completed` **in the same database transaction** only when V1 returned
`saved`. Invalid, stale, unauthorized and duplicate operations never mutate
status. Errors roll back progress and receipts together. Existing Player V1
reads, grants, receipt semantics and actions remain available and unchanged.

## Safety / prerequisites

- No canonical universe, Studio draft, OUTLAND Passport, public release, RLS,
  policy, or source document changes.
- Complete DB CI: clean migration replay, historical baselines, read-only
  catalog/security checks, rollback-only lifecycle fixture, V1 concurrency,
  and V1 atomic ledger rehearsal without V2.
- Complete Player CI on the associated application PR with feature OFF by
  default and tests covering terminal/nonterminal server-derived values.
- Before the production DB migration: inspect latest dependency snapshots and
  exact migration diff; fresh encrypted backup and isolated restore proof
  (with recovery custody); review relevant RLS/grants and migration ledger;
  explicit founder approval of this precise production SQL and window.
- Stage on demand for this trusted RPC change; staging is optional for routine
  UI work but recommended for this security-sensitive migration.
- Database first, then Player production code; enable the opt-in server
  `PLAYER_GAMEPLAY_COMPLETION_PERSISTENCE_APPROVED=approved` only after
  verified V2 role/transaction tests and a production deployment. Do not add
  any NEXT_PUBLIC completion flag.
- Never leak a service-role key, raw answer keys, progress event history, or
  contact details to the browser.

## Existing terminal run (Novi Sad)

**Do not automatically rewrite** the current 78-event, `in_progress` run.
Its screen is terminal but V1 lacks a trusted completion record. The V2 RPC
only marks completion on a new, validated terminal action and deliberately
does not falsely infer old status from JSON shape.

A separate founder-approved, evidence-backed one-off correction can update
that specific row after independently verifying engine replay to `complete`,
actor/version/hash/sequence, and a backup. That correction is **NOT** included
in the migration, and must never be generalized by counting seven puzzles.

## Rollback

1. Set Player completion flag OFF and redeploy (the V1 adapter remains intact).
2. Verify no in-flight V2 action and confirm database state.
3. If necessary, REVOKE EXECUTE from `service_role`, then
   `DROP FUNCTION public.sideworld_player_run_apply_v2(uuid,uuid,uuid,text,integer,jsonb,boolean)`
   under separate authorization.
4. Preserve `quest_runs`, already completed statuses, run receipts, tester
   grants and audit rows. Do not roll back historic migrations or delete
   completion evidence.

## Acceptance

- Terminal transition writes `status=completed` in same CAS transaction.
- Earlier actions remain `in_progress`; completed runs cannot advance.
- Duplicate request IDs return prior receipt without new events.
- Revoked/other actors cannot complete a run.
- Old service-only V1 RPC ABI and stored runs remain readable.
- Current local fixture rollback leaves zero permanent fixture rows.
- Feature-disabled Player continues using V1 even after application release.
