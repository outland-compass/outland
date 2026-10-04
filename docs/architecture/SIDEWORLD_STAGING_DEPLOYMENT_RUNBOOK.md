# SIDEWORLD Phase 1B: staging-only deployment runbook

**Status: EXECUTED on 2026-10-04** from approved SHA `63b0012` (record: `SIDEWORLD_STAGING_REHEARSAL_EVIDENCE.md`, section 8). Kept as the reference procedure.

**Scope:** apply the 10 pending migrations to **outland-staging** (`clgpxvyflycudzhdzjlv`) only.
**This runbook does not authorize execution.** Run it only after written founder approval that names the exact PR #29 commit SHA.
Production (`huzcukdovavejejwohey`) is out of scope. Every script below refuses that ref.

**Evidence:**
- [`SIDEWORLD_STAGING_REHEARSAL_EVIDENCE.md`](SIDEWORLD_STAGING_REHEARSAL_EVIDENCE.md)
- [`SIDEWORLD_STAGING_GO_NO_GO.md`](SIDEWORLD_STAGING_GO_NO_GO.md)

The whole sequence below, steps 2–7 plus the rollback, was rehearsed on a restored staging snapshot using these exact scripts.

## 0. Ground rules

- **Never use `--linked`, never run `supabase link`, and never run from your everyday repo checkout.** That checkout's CLI link (`supabase/.temp/project-ref`) pointed at **production** until it was removed on 2026-10-04; never re-link it. Always pass an explicit `--db-url`.
- **Keep the password out of everything except `PGPASSWORD`.** Never put it in a URL, on a command line, in shell history, in a file or in a log. `scripts/staging/staging-session.ps1` reads it as a SecureString into `PGPASSWORD` only. Don't run with `Set-PSDebug -Trace`.
- **Never** pass `--include-seed`, `--include-roles` or `--include-all` to `db push`, and never run `seed.sql` against staging.
- **Do not rename, insert or update world records.** Staging intentionally keeps its legacy `RIVERKEEPER` and `ALIKI` codes.
- **Every "STOP" means:** stop, change nothing further, record the output, and escalate.
- **Tools:** Docker Desktop running, Node/npx, Supabase CLI pinned as `npx --yes supabase@2.119.0`, Windows PowerShell.

## 1. Prepare a clean, unlinked deployment checkout

```powershell
$Sha = '<approved PR #29 commit SHA>'
git -C C:\CODE\OUTLAND\outland fetch origin sideworld/legacy-universe-cleanup-plan
git -C C:\CODE\OUTLAND\outland worktree add --detach C:\deploy\outland-sideworld-1b $Sha
Set-Location C:\deploy\outland-sideworld-1b
git rev-parse HEAD                               # must equal $Sha
Test-Path supabase\.temp\project-ref             # must be False (not linked to anything)
(Get-ChildItem supabase\migrations\*.sql).Count  # must be 18
gh run list --commit $Sha --workflow "Database CI" --json conclusion --jq '.[0].conclusion'  # must be success
```

## 2. Fresh backup and its verification (mandatory)

The backup from 2026-10-03 proves the method works. You still need a **new** backup immediately before deploying.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\staging\backup-staging.ps1          # prompts for the staging password
powershell -ExecutionPolicy Bypass -File scripts\staging\verify-backup.ps1 -BackupDir $HOME\outland-backups\staging-<timestamp>
```

- `verify-backup.ps1` must end with `VERIFY: ALL CHECKS PASSED`. It checks:
  - SHA-256 of every file;
  - `pg_restore --list` of the full dump (migration history, candidates and worlds present);
  - the inventory cross-checks.
- Record the SHA-256 of `staging-full.dump`.
- The backup is written outside Git, to `$HOME\outland-backups`, and the script refuses any Git work tree. **Never commit backup files.**
- **STOP** if any check fails, or if `staging-full.dump.FAILED` exists.

## 3. Open the staging session and verify the target

```powershell
. .\scripts\staging\staging-session.ps1          # prompts once; refuses the production ref
$StagingDbUrl                                    # postgresql://postgres.clgpxvyflycudzhdzjlv@aws-1-eu-west-1.pooler.supabase.com:5432/postgres?sslmode=require
Invoke-StagingSql scripts\staging\sideworld-1b-pre-deploy-target-check.sql
npx --yes supabase@2.119.0 migration list --db-url $StagingDbUrl
```

- `pre-deploy-target-check.sql` runs in a read-only transaction. It must print `TARGET VERIFIED`. It checks that the target has:
  - exactly 8 recorded versions ending at `202609030001`;
  - the 7 candidate IDs, each with its rehearsed row hash;
  - 8 worlds, with `RIVERKEEPER` present and `RAFTER` absent;
  - no `universe`, `passport` or `infrastructure` schema.
- `migration list` must show 8 versions applied remotely, and these 10 only locally:
  `20260912141712, 20260912141742, 20260912145301, 20260913141314, 20260913141954, 20260917110721, 202609190001, 20260919100334, 202610020001, 202610020002`.
- **STOP** if any of this differs. If staging data changed since the rehearsal, take a new backup and re-rehearse on it first.

## 4. Phase A: the 8 historical migrations

Hold the two SIDEWORLD files back so the checkpoint can run between the phases:

```powershell
New-Item -ItemType Directory -Force ..\sideworld-hold | Out-Null
Move-Item supabase\migrations\20261002000*_sideworld_*.sql ..\sideworld-hold\
npx --yes supabase@2.119.0 db push --db-url $StagingDbUrl --dry-run
npx --yes supabase@2.119.0 db push --db-url $StagingDbUrl          # confirm with Y only if the list matches
```

The dry run, and then the confirmation prompt, must list **exactly** these 8, in this order. The CLI applies them in lexicographic filename order; never re-sort them numerically.

`20260912141712_wanderer_mobile_radar`, `20260912141742_wanderer_benchmark_image`, `20260912145301_wanderer_decision_layer`, `20260913141314_universe_v0_core_and_passport_journey`, `20260913141954_greenhill_universe_node_v0`, `20260917110721_pod_radar`, `202609190001_discovery_signal_promotion`, `20260919100334_add_poseljani_pod_radar_signal`.

The final JSON line must show `"seeds":[]`.

## 5. Checkpoint between the phases (read-only)

```powershell
Invoke-StagingSql scripts\staging\sideworld-1b-checkpoint.sql
```

- It must print `CHECKPOINT PASSED`, which means:
  - 16 versions;
  - only `stay` legacy nodes;
  - no frontiers or spots;
  - no `infrastructure` schema yet.
- **STOP** otherwise, and do **not** run Phase B. Staging at 16 versions is a consistent, usable state.

## 6. Phase B: the 2 SIDEWORLD migrations

```powershell
Move-Item ..\sideworld-hold\*.sql supabase\migrations\
npx --yes supabase@2.119.0 db push --db-url $StagingDbUrl --dry-run    # exactly 202610020001, 202610020002
npx --yes supabase@2.119.0 db push --db-url $StagingDbUrl
```

## 7. Post-deployment validation

```powershell
Invoke-StagingSql scripts\staging\sideworld-1b-post-deploy-validate.sql
Invoke-StagingSql supabase\tests\verify-sideworld-bases.sql
Invoke-StagingSql supabase\tests\verify-schema.sql -PreSql "set outland.world_canon = legacy_compatible"
npx --yes supabase@2.119.0 migration list --db-url $StagingDbUrl    # 18 applied, 0 local-only
Close-StagingSession
```

- **`post-deploy-validate.sql`** is read-only and must print `POST-DEPLOY VALIDATION PASSED`. It checks:
  - **Ledger:** 18 versions, including all 10.
  - **Candidates:** all 7 have the same `world_id` (`OUTLAND_WORK`), and their original values are hash-identical (only the added `development_model` column is excluded).
  - **Worlds:** exactly one floating River/GUARDIAN/FLOW world, and the `OUTLAND_WORK` identity is intact.
  - **Bases:** base and audit parity with every legacy stay node.
  - **Access:** RLS is enabled and nothing is exposed to `anon` or `authenticated`.
- **`verify-sideworld-bases.sql` and `verify-schema.sql`** contain only assertions and end in `ROLLBACK`.
- **Write-path suites:** `verify-workflow-security.sql` and `diagnose-compass-promotion.sql` create rolled-back test data, including `auth.users` rows. Run them on staging only with explicit approval, the first with `-PreSql "set outland.world_canon = legacy_compatible"`. Both pass on the restored snapshot and in CI.
- **Record:** PR SHA, backup SHA-256, all command outputs and timestamps. Do not record credentials.

## 8. Failure recovery and rollback

The CLI applies **each migration in its own transaction**. A failing migration leaves nothing behind and is not recorded, but every migration before it stays committed (tested).

| Situation | Action |
| --- | --- |
| A check fails in steps 1–3 | Nothing was changed. STOP. |
| A Phase A migration fails | That version rolled back and the earlier ones stayed. Run `migration list` to see the state. **Do not retry blindly.** The historical migrations change data and have no down scripts, so recover by **fix-forward** (a reviewed follow-up migration) or by a **backup restore** (below). |
| Checkpoint fails | Do not run Phase B. Staging stays at 16 versions. Escalate. |
| `202610020002` (backfill) fails | The foundation (`202610020001`) stays and the backfill is fully rolled back. Either fix the cause and rerun the Phase B `db push`, which applies only `202610020002` (tested), or roll back SIDEWORLD (next row). |
| Roll back SIDEWORLD (full or partial state) | `Invoke-StagingSql scripts\staging\sideworld-1b-rollback.sql`. It's one transaction with no `CASCADE`, and it aborts without changes if anything else lives in `infrastructure`. Afterwards there are 16 versions and the schema equals the Phase A state (tested from both the full and the partial state). Re-applying regenerates the base UUIDs. |
| Post-deploy validation fails | For a SIDEWORLD-only failure (bases, audit, RLS), roll back SIDEWORLD. For a candidate or world failure, STOP, keep staging unchanged and escalate for a restore decision. |
| Full restore (last resort) | Restore the step 2 backup: run `roles.sql`, `schema.sql`, `SET session_replication_role = replica`, `data.sql` in one transaction as a privileged role, then `pg_restore -n supabase_migrations` from `staging-full.dump`. Rehearsed into a disposable local stack (about 40 s, byte-identical). **Restoring into the hosted staging project, or into a new Supabase project, was not rehearsed.** It needs a separate approval and plan. |
| Password exposed | `Close-StagingSession`, then rotate the staging database password in the Supabase dashboard. |

Afterwards, `git worktree remove C:\deploy\outland-sideworld-1b`. Keep the backup outside Git until the deployment has been accepted.
