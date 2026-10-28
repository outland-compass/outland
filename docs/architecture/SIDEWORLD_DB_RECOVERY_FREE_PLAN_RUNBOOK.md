# SIDEWORLD — Free Plan Database Recovery Gate

**Status (reconciled 2026-10-28): Previous production backups and isolated APPLICATION-TABLE restores ARE VERIFIED. A fresh, retained and independently recoverable artifact for the next production migration is NOT VERIFIED. This Group-specific full restore/parity test is separate and remains unverified.**

Owner: OUTLAND Supabase. Historical evidence last checked: 2026-10-28.

## LOCKED cross-repository recovery evidence (2026-10-28)

**Do not repeatedly restart backup/restore planning or claim that SIDEWORLD has never been backed up/restored.** The primary, ALREADY IMPLEMENTED process is in [Studio `.github/workflows/production-backup-restore.yml`](https://github.com/outland-compass/sideworld_studio/blob/main/.github/workflows/production-backup-restore.yml). It uses read-only production snapshots, a network-disconnected application restore and fingerprint verification, encrypted archives and 7-day GitHub artifact retention. Studio [recovery runbook](https://github.com/outland-compass/sideworld_studio/blob/main/docs/PRODUCTION_BACKUP_RESTORE.md) owns the detailed, evidence-first protocol.

- Verified local production dumps with SHA256/inventory PASS: **Oct 4, Oct 6 and Oct 7, 2026**, recorded in original ThinkPad operator logs. Existence of these directories **today** has not been rechecked.
- Verified GitHub production backup plus isolated application restore: [Oct 11 run 38158657515](https://github.com/outland-compass/sideworld_studio/actions/runs/38158657515), [Oct 14 run 38550055892](https://github.com/outland-compass/sideworld_studio/actions/runs/38550055892), **[Oct 19 run 38644178274, attempt 4](https://github.com/outland-compass/sideworld_studio/actions/runs/38644178274)**. Last run logs `PASS: backup encrypted and application restore fingerprints verified`.
- The Oct 19 GitHub Actions encrypted artifact, retained **7 days**, has **zero downloadable artifacts** as checked 2026-10-28. A historic PASS is real but **does not constitute a current protected recovery point**.
- The Studio process demonstrates scoped **application-data recovery**, **not** complete Supabase-managed Auth/Storage objects/Edge Functions/Vault/role-semantics recovery. The `outland` Group recovery canary parity and restore validation described below is an additional distinct gate, not a contradiction.

**Operational decision:** First check those runs, currently available encrypted artifacts, and any verified local/off-GitHub copy. If backup is stale or expired, **rerun the existing Studio manual workflow** with its exact reviewed `main` SHA, verify a new PASS and save encrypted archive + digest OFF GitHub before expiration. Do not write a second backup engine. Do not apply Group or Location Intelligence V3 production DDL without separate explicit founder approval. Studio's workflow NEVER applies migrations.

For SIDEWORLD Location Intelligence V3: [OUTLAND PR #95](https://github.com/outland-compass/outland/pull/95) merged at `a63d0e52ebbe420a60e394d7274b4de42f9091a5`; its **production migration was not authorized or applied as of 2026-10-28**.

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
4. From the checked-out OUTLAND repository, write exports to an encrypted directory **outside the checkout**. Replace the placeholder path, never check it into Git:

```bash
supabase db dump --linked -f /ENCRYPTED-BACKUP/roles.sql --role-only
supabase db dump --linked -f /ENCRYPTED-BACKUP/schema.sql
supabase db dump --linked -f /ENCRYPTED-BACKUP/data.sql --use-copy --data-only
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
| Historical local production backups and scoped application restore | **VERIFIED (Oct 4/6/7; Oct 11/14/19)**; see evidence above |
| Current fresh protected logical backup | **NOT VERIFIED**; last GitHub artifact expired; check private local copies / rerun existing Studio workflow |
| Historical isolated application restore | **VERIFIED**, last Oct 19; **fresh restore and Group-specific parity not yet verified** |
| Group SQL real PostgreSQL disposable CI | Passed in GitHub Actions 2026-10-24 (confirm exact PR SHA) |
| Group concurrent write and privilege tests | Passed in disposable CI 2026-10-24 (confirm exact PR SHA) |
| Reviewed CLI-generated additive migration with green CI | PR #87 prepared; merge and full CI status require final verification |
| New immutable Couple/Team quest release | Not yet available |
| Production activation flags | Remain OFF |

Only after every gate is proven should the authorized Group DDL be executed on production. **Approval to continue development does not override a failed recovery gate.**

## Safe rollback

Switch Group HTTP flags OFF; deny Group RPC EXECUTE using a reviewed additive migration; retain Group audit data. Never rewrite immutable quest releases or remove existing Solo tables. An actual database restore is a separately considered incident action, not a substitute for safe feature rollback.

This document does not itself prove backup or restore readiness.

## SIDEWORLD-specific restoration canaries (added 2026-10-26; not yet executed against production)

The existing OUTLAND inventory captures legacy worlds/candidates but not sufficient SIDEWORLD `canon`, `geo`, `player` and release-integrity metadata. A new **read-only** `scripts/production/sideworld-group-canaries.sql` is part of the protected local Windows backup workflow in `scripts/production/backup-production.ps1`.

This produces five local CSVs under the already ACL-restricted backup folder: `sideworld-counts.csv`, `sideworld-release-canaries.csv`, `sideworld-rls.csv`, `sideworld-group-objects.csv`, `sideworld-extensions.csv`. They capture row counts, immutable release hashes (not contents), RLS/role-SELECT status, Group migration/object presence and extension versions. No auth identities, passwords, invitation secrets, scene text or role clues are exported in the canaries. **The database dumps themselves remain highly sensitive and must be stored on an encrypted local volume; ACLs alone do not provide at-rest encryption.**

On the trusted Windows workstation, in a checked-out OUTLAND repository and with Docker running, use the existing password-prompting backup script only when prepared to handle sensitive data:

```powershell
.\scripts\production\backup-production.ps1 -OutRoot 'D:\Encrypted\OutlandBackups'
.\scripts\production\verify-production-backup.ps1 -BackupDir 'D:\Encrypted\OutlandBackups\production-YYYYMMDD-HHMMSS' -RequireSideworldGroupCanaries -RequireGroupPreMigrationState
```

The `RequireSideworldGroupCanaries` switch deliberately enforces additional checks without breaking inspection of historical OUTLAND backups. The separate `RequireGroupPreMigrationState` switch confirms the **pre-migration** condition: the Group objects and applied migration entry are all absent. Do not use this switch for post-migration backups. Re-run all checks on a fresh backup immediately before proposed production DDL.

**Neither generating the files nor passing offline SHA/CSV/pg_restore-list checks proves the backup can be successfully restored.** The isolated Supabase/Postgres 17 restore rehearsal with canary parity (including auth, releases, access, run receipts and extensions) remains mandatory, as does separate explicit authorization for Group production DDL and another for feature activation.

An isolated GitHub CI exercises this read-only SQL only against disposable Supabase; no production credential, backup dump, CSV artifact or remote migration is used. That rehearsal proves script compatibility, not current production backup readiness.

## Compare protected backup canaries with a successful isolated restore

A separate offline comparator `scripts/production/compare-sideworld-restore-canaries.ps1` is available for the recovery rehearsal. **It does not perform the restore**, fetch production data, grant any access, apply Group SQL or activate multiplayer. Both input directories must contain the five inventory CSVs produced by `sideworld-group-canaries.sql` on the source and the isolated-restored instance.

From a trusted Windows terminal, after exporting canaries from the isolated restored database:

```powershell
.\scripts\production\compare-sideworld-restore-canaries.ps1 -BackupDir 'D:\Encrypted\OutlandBackups\production-YYYYMMDD-HHMMSS' -RestoreDir 'D:\Encrypted\IsolatedRestore\canaries-before-group'
```

This requires exact metadata parity for source/target table counts, immutable release hashes, installed extension versions, all pre-existing `canon`/`player`/`geo` RLS/grants, and the absence of the yet-unapplied Group migration. **Treat any mismatch as a stop condition**, diagnose it privately, and do not weaken checks merely to obtain PASS.

After intentionally applying the reviewed Group migration in the **isolated restored instance only**, export the metadata again into another fresh directory and run:

```powershell
.\scripts\production\compare-sideworld-restore-canaries.ps1 -BackupDir 'D:\Encrypted\OutlandBackups\production-YYYYMMDD-HHMMSS' -RestoreDir 'D:\Encrypted\IsolatedRestore\canaries-after-group' -AfterGroupMigration
```

The post-migration comparison requires all prior canonical row counts and immutable hashes to remain unchanged, all prior RLS/grants unchanged, the three new Group tables RLS-enabled with no direct anon/authenticated/service table SELECT, the Group migration recorded, and all six expected RPC names present. **RPC existence does not establish correct privileges, concurrency safety, or permissions**: perform the existing isolated SQL privilege/concurrency test suite separately.

An entirely synthetic offline GitHub CI validates comparator behavior against matching pre-migration snapshots, after-migration Group additions and deliberate corrupted release metadata. It never processes actual production backup files or transmits real canaries. This additional check is not a substitute for whole-database restore tests, storage asset restoration, authorization testing, owner/operator approval, or field QA.
