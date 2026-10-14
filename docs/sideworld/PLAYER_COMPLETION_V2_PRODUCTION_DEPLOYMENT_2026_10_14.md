# SIDEWORLD Player Completion V2 — Production Migration Record

**Executed:** 2026-10-14 (UTC), on `outland` Supabase `huzcukdovavejejwohey`.

## Source and explicit approval

Founder approved production application of the exact SQL originally reviewed
as `20261014230000_sideworld_player_runtime_completion_v1.sql` in OUTLAND
PR #73, conditional on passing CI and fresh encrypted backup + isolated
restore verification. The SQL content blob remained **unchanged**, Git blob
SHA `2594116780ee48d3b47ec7b7275959ed0c58a65f`.

OUTLAND PR #73 merged at `2536146128740364973205e7846b66cc33931414`.
All five Database CI jobs and Web CI passed before application. The same
SQL was rehearsed first on isolated Supabase staging, with role checks and
synthetic transaction tests inside ROLLBACK.

## Backup / restore gate

Initial encrypted backup from 2026-10-14 10:34 UTC was too old and did not
cover `player` application-table restore fingerprints. New protected
workflow run `38643887916` failed at isolated application restore due to
missing dependency; no production writes and no backup artifact from that run.

Studio PR #46 added the `player` schema to application restoration, and
asserted all required `canon.quest_releases`, `player.qa_access`,
`player.quest_runs`, `player.run_receipts` and `player.qa_operator_audit`
tables must be fingerprinted.

Protected [GitHub Actions run #38644178274](https://github.com/outland-compass/sideworld_studio/actions/runs/38644178274)
completed successfully on 2026-10-14. Safe logs explicitly confirmed
`verify-restored-fingerprints`, `encrypt-verified-backup`, and
`PASS: backup encrypted and application restore fingerprints verified`.
GitHub retained encrypted-only artifact `production-backup-38644178274`
ID `11931697933`, 527729 bytes, expires 2026-10-21T22:04:41Z,
ZIP SHA256 `2589ff330b287a516adc5f4d9ddc13e008b7e0d7c9c5359b32b5d424f1d7eb03`.

This proves an isolated **application-table** restore and encrypted archive
round-trip; it does NOT claim full Auth/Storage service recovery or independent
off-site custody.

## Production application and postflight

The Supabase migration tool applied the exact approved SQL once, recording
the provider-generated canonical ledger entry
**`20261014220543_sideworld_player_runtime_completion_v1`**. This PR
renames the repository migration file to match that actual *production*
version with identical SQL bytes; no second migration is intended.

Production read-only postflight:
- `public.sideworld_player_run_apply_v2(...,boolean)` exists.
- `service_role` EXECUTE = true; `anon` / `authenticated` EXECUTE = false.
- Existing `sideworld_player_run_apply_v1` remains executable by service role.
- Release count 1, grant count 1, gameplay runs 1,
  `in_progress` 1, `completed` 0, receipts 16, audit records 2.
- No public release, regrant, new run, or legacy progress backfill.

## Ledger reconciliation

The migration management API generated staging version
`20261014215424` for the same SQL. A staging-only, guarded atomic
ledger reconciliation then changed **only** that version to the canonical
production version `20261014220543`. Before this metadata correction,
read-only checks proved both databases had the same one-statement migration
fingerprint `76d22bbbd4a3a6312e14cab613bc35df` and the same V2 function
definition MD5 `a2429e349bbafce4e517648a688e9411`; the update required
exactly one staging ledger row and rejected collisions/content drift.
Postflight re-verified version, name and SQL fingerprint matched in both
databases. No SQL replay, data changes or production history edits occurred.
Do not reapply the migration under another timestamp.

## Player activation

At SQL postflight, production Player app commit
`868abeae7badbfeaa3953e0520a8f81f2285d406` was READY.
Server-only `PLAYER_GAMEPLAY_COMPLETION_PERSISTENCE_APPROVED` was still
absent: V1 remained active. Enabling and verifying V2 is a separate
controlled runtime rollout, not implied by DDL application itself.

## Rollback

Disable the Player V2 completion flag and redeploy, restoring use of V1.
If a database rollback is required, under explicit DBA authorization,
revoke service-role EXECUTE and drop *only* the new
`sideworld_player_run_apply_v2` RPC. Preserve completed states and all
existing content, run histories, receipts, grants, audit rows and migration
history. Never reverse existing completed statuses or replay Player V1.
