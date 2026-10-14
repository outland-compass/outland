# SIDEWORLD / OUTLAND — production migration-history source recovery

**Date:** 2026-10-14. **Environment:** read-only inspection of OUTLAND production `huzcukdovavejejwohey` and staging `clgpxvyflycudzhdzjlv`. This file is a reconciliation record, NOT a production rollout approval.

## Finding

The initial OUTLAND repository tree lacked **six historical SQL migration files** even though both managed Supabase databases had recorded them as applied. The missing files caused the new controlled-transaction CI to fail its exact 38-prior-migration baseline, despite the Player SQL and four established database CI paths passing.

**Source of truth recovered:** `supabase_migrations.schema_migrations.statements[1]` for each historical version in production, cross-checked for **byte-for-byte equality** with staging's corresponding record. Each recovered GitHub file exactly matches its recorded source SQL, verified again by fetching the committed file. No live database changes were performed.

| Version | Recovered migration name | Production and staging MD5 |
| --- | --- | --- |
| 20261008130544 | `sideworld_studio_universe_catalog` | `bfde03463f79583eed31019c0e6c80e8` |
| 20261008130547 | `sideworld_studio_guarded_root_writes` | `2ad6899d32d16c2ab29cdfdb2c3e759f` |
| 20261008130549 | `sideworld_studio_guarded_canon_writes` | `cb7ff3cb9af50d93c97c2bab0f661f5d` |
| 20261008135838 | `fix_guarded_faction_dispatch` | `685f95f2b0559bb0f3dddc20451fb78a` |
| 20261008184928 | `sideworld_character_media_v1` | `eb9bb28aea5799cb8cca7f0779391c6c` |
| 20261009052334 | `sideworld_character_media_rpc_v1` | `0f7efc864722d30bf73209e0d296c43b` |

The migrations contain previously deployed Studio catalog/admin RPC definitions and character-media setup. The recovered files **are not empty placeholders**. No credential-like literals were identified in the basic automated scan; however, repository/security review remains required before merging.

## Why restoration is safer than faking the ledger

Local clean migration replay should build the historical application schema by actually running the original SQL. Pretending that the missing migrations were applied by inserting fake history rows would hide missing functions, policy defaults or storage configuration.

The real production and staging migration ledgers previously had 38 same-name historical records with three differing version timestamps. Those three known differences remain documented; **this recovery does not rewrite either ledger**. Local canonical OUTLAND history now contains all six recovered files under their actual production versions.

## Verification required

- [x] Check production and staging source SQL bytes match for all six.
- [x] Restore exact original SQL into GitHub Draft PR #70 with original version/name.
- [x] Re-fetch restored repo blobs and compare each string byte-for-byte with production ledger.
- [ ] Re-run all OUTLAND Database CI historical migration replay paths, including the *new* exact-version atomic transaction test. Review any new CI failures against the original SQL rather than weakening the baseline checks.
- [ ] At final approval, confirm 38 clean migration records on the reviewed baseline; production must independently still have only those 38 prior records, not an unreviewed newer schema.

**Operational boundary:** This is a Git source-control reconciliation only. Neither production nor staging databases are modified by restoring GitHub files. Do not merge the Draft #70, execute production DDL, alter existing migration ledger rows or enable QA/gameplay without separate authorization.
