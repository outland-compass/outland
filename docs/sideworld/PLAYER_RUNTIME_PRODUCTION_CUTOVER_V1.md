# SIDEWORLD Player V1 — controlled production cutover checklist

**Status:** PREPARATION ONLY — production SQL NOT authorized or applied. Draft [OUTLAND PR #70](https://github.com/outland-compass/outland/pull/70). The 2026-10-14 migration has already passed staging and CI. SIDEWORLD is the consumer platform; OUTLAND owns this shared Supabase migration, not the SIDEWORLD brand or universe catalog.

## Immutable change scope

| Item | Pinned evidence |
| --- | --- |
| Production Supabase project | `huzcukdovavejejwohey` |
| Previously verified staging project | `clgpxvyflycudzhdzjlv` |
| Migration file | `supabase/migrations/20261014104136_sideworld_player_runtime_v1.sql` |
| Target ledger version/name | `20261014104136` / `sideworld_player_runtime_v1` |
| Audited SQL Git blob SHA | `8fcca2a8a0eec82f4dd899412e14848d279b9295` |
| SQL changes | Four new private tables, eight service-role-only public RPCs, internal helpers/trigger; zero seeds/backfill |
| Original schema/rehearsal evidence | [PLAYER_RUNTIME_MIGRATION_V1_REVIEW.md](PLAYER_RUNTIME_MIGRATION_V1_REVIEW.md) |
| Verified backup/isolated restore | [Studio Actions #38550055892](https://github.com/outland-compass/sideworld_studio/actions/runs/38550055892) |
| Backup artifact expiry | 2026-10-21 10:34:35 UTC |
| Studio QA interface | Merged Studio PRs #38/#39, *code only and flag OFF* |

## 1 — No-write readiness gate

Run from the reviewed OUTLAND PR #70 tree with Node.js (and `psql` when performing a live read-only check):

```bash
node --test scripts/sideworld/player-runtime-preflight.test.mjs
node scripts/sideworld/player-runtime-preflight.mjs --check-file
# On an authorized operator's secured terminal, with the project's existing
# production connection string supplied via protected environment variable:
node scripts/sideworld/player-runtime-preflight.mjs --db-preflight
```

The script has **no write/apply mode**, verifies the audited SQL Git blob SHA, rejects non-production connection targets, checks PG17, 38 prior migrations, exact prior version `20261012151318`, no existing Player runtime objects or matching RPCs, and compares all existing four referenced tables' constraint/index/trigger/RLS fingerprints against the 2026-10-14 production read-only audit. It uses `default_transaction_read_only=on`, a short statement timeout and never prints credentials.

**STOP** if SQL fingerprint, migration inventory, schema dependencies, project reference, restore evidence or feature flags differ. Any legitimate later database change requires a fresh review of this pinned preflight rather than bypassing it.

## 2 — Recovery and approval gate

Before any actual DDL:
- Retain a **fresh, encrypted** application-level production dump off GitHub before artifact expiry; record verified SHA256. Keep the encryption key in a separate protected vault. Successful local application-data fingerprint restore of Oct 14 is evidence of this subset only, not a complete managed Supabase Auth/Storage disaster recovery drill. Explicitly record what managed services and object bytes are excluded.
- Recheck the migration and source object fingerprints against production immediately before change, confirm GitHub PR+CI green, and get the founder's **explicit authorization naming the exact SQL version, target, rollback plan and time window**. A generic 'continue' or an earlier staging approval never authorizes production DDL.
- Agree a short maintenance/low-traffic window; leave all Studio and Player QA/gameplay flags **OFF**. Verify current production backup is still valid if operations occur after Oct 14.
- Confirm the application service role is server-only and production Auth/session/WAF/audit environment is not enabled accidentally. The Vercel firewall config was NOT independently verified as active, so rate limiting is still a gating item for activation.

## 3 — Version-preserving production application method — NOT YET APPROVED

**Do not use `supabase db push` blindly.** Production and staging have three existing history timestamps that differ even though matched canonical table schemas and selected functions align. `supabase apply_migration` via the connector generated a new timestamp on staging; the production audit requires preserving the canonical `20261014104136` version.

A controlled execution implementation must be code-reviewed and exercised against a **disposable PostgreSQL 17 target using the exact reviewed SQL**. It must:

1. Validate the production project and repeat all read-only preflight checks inside the locked application window, verify `20261014104136` is absent in the ledger, and acquire a transaction-scoped advisory lock to prevent concurrent migration writers.
2. Execute ONLY the pinned, already-approved SQL; in the **same atomic transaction**, record the exact version/name in `supabase_migrations.schema_migrations` consistent with the existing Supabase migration ledger (`statements` array). This is a one-off, explicit, reviewed path; never rewrite any of the three previous historical migration versions.
3. On any SQL/ledger error, **ROLLBACK** both DDL and ledger changes. No `CASCADE`, destructive schema reset, fixtures, backfills, seeded players or user modifications.
4. Re-query the ledger plus four tables, RLS/policies, eight service-only RPC grants and empty runtime data. Independently verify the Client-denial and rollback-only synthetic functional tests before calling the cutover successful.
5. Record the actual transaction result and change identifier in the private operations log without secrets or any authoring content.

**This version-preserving writer is NOT implemented or verified yet.** Do not attempt hand-entered production SQL to fill this gap, and do not mark this checklist ready for cutover until the reviewed runner exists and is tested. This is deliberately a stop condition.

## 4 — Abort, rollback and forward-fix strategy

Before any changes: do nothing. On transaction error: PostgreSQL transaction rollback must leave all four objects and ledger row absent.

After a committed apply **with zero release/grant/run data**, keep app flags off and assess a narrowly reviewed cleanup migration that revokes the eight RPCs and removes ONLY the four newly created tables/functions/trigger in dependency order (see [original rollback section](PLAYER_RUNTIME_MIGRATION_V1_REVIEW.md)). Do not drop canonical Studio draft tables, universes or Passport objects.

If real content or player sessions already exist, **never drop tables** as a quick rollback. Re-disable Studio/Player feature flags and use a reviewed compatible forward fix; consider full restore only against a verified recovery point with an explicit owner decision.

## 5 — Activation and first private quest are separate authorizations

Production schema ≠ public release, QA release, actual customer access or Vercel deploy.

Before enabling real gameplay: verify Studio operator Auth and OWNER/ADMIN binding end-to-end, canonical Player-derived hash for the exact Studio V2 revision, durable operator audit, distributed rate limiting/access restriction, private release+tester grants, no client answer-key disclosure, mobile/field tests and content/media/location rights. Keep public publishing disabled. Founder and Sara test through ordinary, non-admin Player identities.

## 6 — Evidence to collect in the future

- Final PR#70 commit and fully passing GitHub CI for that head.
- Fresh production read-only preflight output (non-secret) and approved operation ID.
- Backup artifact SHA256 + successful isolated restore record + separate key custody confirmation.
- Disposable migration writer success and failure/rollback proof.
- Founder authorization for exact production DDL and target.
- Production postflight (migration version, zero player rows, RLS/grants verified) and next, separately authorized, protected real QA run.

**Current decision:** stay production-first, but do not confuse an inert schema preparation with permission to execute high-risk RLS/SECURITY DEFINER changes on the live database.
