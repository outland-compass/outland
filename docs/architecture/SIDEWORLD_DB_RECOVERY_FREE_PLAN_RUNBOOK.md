# SIDEWORLD — Free Plan Database Recovery Gate

**Status: Runbook only; backup and restore are NOT verified.**

Owner: OUTLAND Supabase. Last checked: 2026-10-23.

## Grounded baseline

- Organization: `outland`, Free Plan; project `huzcukdovavejejwohey` is production.
- Optional staging `clgpxvyflycudzhdzjlv` returned a hibernation notice; do not rely on its data or readiness.
- Existing canonical release and Solo runtime must remain untouched by proposed Group SQL.
- Official guidance: [Database Backups](https://supabase.com/docs/guides/platform/backups) recommends `supabase db dump` for Free accounts. [Backup and restore with CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore) is the authoritative recovery procedure.

## Export on a trusted local workstation

Install Docker Desktop, a reviewed Supabase CLI version and the PostgreSQL client. Never disclose project DB passwords in chat or CI logs. Create an encrypted folder outside the OUTLAND Git checkout.

1. Run `supabase login` using your own CLI session.
2. In a checked-out OUTLAND repository, run `supabase link --project-ref huzcukdovavejejwohey`.
3. Review the installed CLI's `supabase db dump --help`.
4. From the encrypted backup folder, capture three exports:

```bash
supabase db dump --linked -f roles.sql --role-only
supabase db dump --linked -f schema.sql
supabase db dump --linked -f data.sql --use-copy --data-only
```

Treat output as sensitive: auth records may be included. Do not commit, upload as public CI artifacts or send files to chats. Make a second encrypted offline copy with an explicit retention plan. Capture a read-only snapshot of migration versions, table counts, relevant function grants and release hash samples. Storage *objects* need their own export; SQL alone cannot restore objects.

## Isolated restore rehearsal

1. Prepare a **separate disposable** Supabase/self-hosted Postgres 17 environment with compatible Auth, Storage, extensions and platform schema. The target must not resolve to the production host.
2. Use the documented Supabase CLI backup/restore procedure and `psql --single-transaction --set ON_ERROR_STOP=1`. Record all exit statuses. Do not ignore missing roles, extensions or data errors.
3. Match key schema, migration ledger and count/hash evidence to the pre-backup production snapshot (auth users, universes, quest releases, Player access, runs and receipts).
4. Apply the reviewed Group migration to the isolated restore only, then verify group member authorization, invite expiry, unique roles, CAS/idempotency, request replay, private role projections, and absence of regression in Solo.
5. Exercise incident rollback via default-OFF Group flags and revocation of new Group RPC EXECUTE grants. Preserve group rows and old Solo runs.

## Production gate: NO-GO until verified

| Check | Status |
| --- | --- |
| Read-only production schema and migration audit | Performed earlier; repeat immediately before DDL |
| Current protected logical backup | **NOT VERIFIED** |
| Successful isolated restore of that backup | **NOT VERIFIED** |
| Group SQL real PostgreSQL disposable CI | In progress |
| Group concurrent write and privilege tests | Needs final evidence |
| Reviewed CLI-generated additive migration with green CI | Not yet prepared |
| New immutable Couple/Team quest release | Not yet available |
| Production activation flags | Remain OFF |

Only after every gate is proven should the authorized Group DDL be executed on production. **Approval to continue development does not override a failed recovery gate.**

## Safe rollback

Switch Group HTTP flags OFF; deny Group RPC EXECUTE using a reviewed additive migration; retain Group audit data. Never rewrite immutable quest releases or remove existing Solo tables. An actual database restore is a separately considered incident action, not a substitute for safe feature rollback.

This document does not itself prove backup or restore readiness.
