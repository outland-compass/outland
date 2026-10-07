# SIDEWORLD Schema V3.2 — Staging Go / No-Go

**Updated:** 2026-10-07  
**Current verdict: NO-GO for Execute.**  
**Live staging baseline: VERIFIED READ-ONLY.**  
**Target:** staging `clgpxvyflycudzhdzjlv` only. Production `huzcukdovavejejwohey` is never a target.

## Verified

| Item | Status |
| --- | --- |
| Repository baseline: `main` = `2683c548a1c5d28b458f1b84aa84602aebae4957` (PR #35 merged) | VERIFIED |
| PR #35 atomicity change: four migration-local `begin;`/`commit;` wrappers removed, no schema-semantic change | VERIFIED |
| Pinned migration blobs: `108ced4…`, `b06b95c…`, `770723c…`, `9830e84…` | VERIFIED |
| Atomic feature commit `e8634721dc46cb6735e320a441ec45eb8bc5167c`: clean replay/tests/CI/atomic failure drill | PASS |
| Staging project ref/status | VERIFIED READ-ONLY |
| Staging migration ledger: 19 versions, latest `20261004140102` | VERIFIED READ-ONLY |
| Legacy Universe V0 tables absent; `universe.set_updated_at()` retained | VERIFIED READ-ONLY |
| V3.2 tables not present on staging | VERIFIED READ-ONLY |
| `infrastructure.bases` and Passport world FKs still point to `shared.worlds` | VERIFIED READ-ONLY |
| Passport journeys trigger still uses `universe.set_updated_at()` | VERIFIED READ-ONLY |
| Staging API exposure remains `public, graphql_public, shared, land`; `universe/geo/canon` unexposed | VERIFIED READ-ONLY |
| API-role schema privileges match the expected private boundary | VERIFIED READ-ONLY |
| Current staging row counts: worlds 8, candidates 13, activities 23, bases 1, base audit 1, journeys/events 0 | RECORDED READ-ONLY |
| Remote staging/production writes during this update | NONE |

## Why still NO-GO

The updated rehearsal package itself has not yet been re-drilled end to end after these changes:

- atomic-only Execute path;
- new migration blob pins;
- explicit committed-state verification before ledger repair;
- one-version-at-a-time ledger recording;
- `CompleteLedger` recovery mode for schema-committed / ledger-partial state.

## Gates before live staging Prepare

1. **Local disposable-stack re-drill PASS**, including atomic failure injection and partial-ledger recovery.
2. Review package diff and evidence.
3. Commit/push tooling on a dedicated branch and open a PR.
4. Tooling PR CI/review PASS and merge.
5. Create a clean, unlinked detached deployment checkout at the tooling merge SHA.
6. Run `Prepare` against live staging using explicit `-SourceSha <tooling merge SHA>`.
7. `Prepare` must create a fresh verified backup, re-check exact 19-version baseline, fingerprints, API exposure, timeouts and exact four-file dry run.
8. Keep write-path suites OFF for the first rehearsal unless separately approved.
9. Schedule a quiet window with COMPASS writes paused.
10. Separate written founder approval for `Execute`, naming the exact SHA.

## Execute policy

- Only atomic `psql -1` apply of all four wrapperless V3.2 migrations.
- `statement_timeout = 60s`, `lock_timeout = 5s`.
- Schema commit is followed by read-only committed-state verification **before** any migration-history repair.
- Ledger rows are recorded one at a time; failure stops immediately.
- If ledger repair is partial, use the separately approved `CompleteLedger` path; never blindly rerun DDL or `db push`.
- Empty-state rollback is separate approval only; populated V3.2 tables default to forward-fix, not destructive rollback.

## Out of scope

- Production database deployment.
- API grants/exposure for `universe`, `geo`, `canon`.
- Canonical data seeding or `world_outland_map` population.
- `npm run db:types` repair.
- SIDEWORLD Studio/frontend implementation.
