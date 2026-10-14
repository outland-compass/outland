# SIDEWORLD Player V1 — controlled production cutover checklist

**Status (updated 2026-10-14):** Production SQL **authorized, applied once and independently verified**; Player gameplay and Studio QA access remain **OFF**. This is an archived execution plan with historical pre-application steps, **NOT an instruction to rerun** the migration. See [Production deployment evidence](PLAYER_RUNTIME_PRODUCTION_DEPLOYMENT_2026_10_14.md). SIDEWORLD is the consumer platform; OUTLAND owns this shared Supabase migration, not the SIDEWORLD brand or universe catalog.

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

## 1 — Historical no-write readiness gate (completed before first apply)

Run from the reviewed OUTLAND PR #70 tree with Node.js (and `psql` when performing a live read-only check):

```bash
node --test scripts/sideworld/player-runtime-preflight.test.mjs
node scripts/sideworld/player-runtime-preflight.mjs --check-file
# On an authorized operator's secured terminal, with the project's existing
# production connection string supplied via protected environment variable:
node scripts/sideworld/player-runtime-preflight.mjs --db-preflight
```

The script has **no write/apply mode**. Before the authorized application it verified the audited SQL Git blob SHA, production project, PostgreSQL 17, **38 historical migrations**, missing Player objects and four referenced source schema fingerprints. **It must now intentionally FAIL against production, which correctly has 39 migrations and four Player tables. Do not bypass or weaken the checks to rerun it.**

**STOP** if SQL fingerprint, migration inventory, schema dependencies, project reference, restore evidence or feature flags differ. Any legitimate later database change requires a fresh review of this pinned preflight rather than bypassing it.

## 2 — Historical recovery and approval gate (completed for original cutover)

Before any actual DDL:
- Retain a **fresh, encrypted** application-level production dump off GitHub before artifact expiry; record verified SHA256. Keep the encryption key in a separate protected vault. Successful local application-data fingerprint restore of Oct 14 is evidence of this subset only, not a complete managed Supabase Auth/Storage disaster recovery drill. Explicitly record what managed services and object bytes are excluded.
- Recheck the migration and source object fingerprints against production immediately before change, confirm GitHub PR+CI green, and get the founder's **explicit authorization naming the exact SQL version, target, rollback plan and time window**. A generic 'continue' or an earlier staging approval never authorizes production DDL.
- Agree a short maintenance/low-traffic window; leave all Studio and Player QA/gameplay flags **OFF**. Verify current production backup is still valid if operations occur after Oct 14.
- Confirm the application service role is server-only and production Auth/session/WAF/audit environment is not enabled accidentally. The Vercel firewall config was NOT independently verified as active, so rate limiting is still a gating item for activation.

## 3 — Version-preserving production application method — COMPLETED ONCE

**Do not use `supabase db push` blindly.** Production and staging have three existing history timestamps that differ even though matched canonical table schemas and selected functions align. `supabase apply_migration` via the connector generated a new timestamp on staging; the production audit requires preserving the canonical `20261014104136` version.

A controlled execution implementation must be code-reviewed and exercised against a **disposable PostgreSQL 17 target using the exact reviewed SQL**. It must:

1. Validate the production project and repeat all read-only preflight checks inside the locked application window, verify `20261014104136` is absent in the ledger, and acquire a transaction-scoped advisory lock to prevent concurrent migration writers.
2. Execute ONLY the pinned, already-approved SQL; in the **same atomic transaction**, record the exact version/name in `supabase_migrations.schema_migrations` consistent with the existing Supabase migration ledger (`statements` array). This is a one-off, explicit, reviewed path; never rewrite any of the three previous historical migration versions.
3. On any SQL/ledger error, **ROLLBACK** both DDL and ledger changes. No `CASCADE`, destructive schema reset, fixtures, backfills, seeded players or user modifications.
4. Re-query the ledger plus four tables, RLS/policies, eight service-only RPC grants and empty runtime data. Independently verify the Client-denial and rollback-only synthetic functional tests before calling the cutover successful.
5. Record the actual transaction result and change identifier in the private operations log without secrets or any authoring content.

The version-preserving SQL renderer and disposable PostgreSQL test were implemented and passed Database CI [#38558777175](https://github.com/outland-compass/outland/actions/runs/38558777175). The **exact reviewed transaction was subsequently executed once after founder approval**, and independent production SQL confirmed the requested ledger version and empty, deny-by-default runtime tables. **Never execute this one-time transaction again.**

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

**Current decision:** The specifically approved production schema application is complete; no rerun. Future work is restricted to version-controlled reconciliation, secure operator audit/rate limits, live Auth integration, QA and independently approved gameplay activation. Production-first does not mean staging is mandatory for small safe code changes.

## 7 — Actual production postflight

Confirmed after the user-authorized one-time transaction on 2026-10-14:
- Production migration version `20261014104136`, name `sideworld_player_runtime_v1`, total history entries **39**.
- Staging and production ledger SQL MD5 both `6c6e1316567539d03e70ea5688ffca6b`, matching 21415 bytes. Original migration blob remains `8fcca2a8a0eec82f4dd899412e14848d279b9295`.
- Four RLS-enabled tables, zero client policies/direct grants; eight `service_role`-only RPCs with restrictive `search_path`; **zero** live releases, grants, runs and receipts.
- OUTLAND PR #70 was initially still Draft after schema application and required source-control reconciliation. Deploying/merging code is distinct from deploying SQL.
- No verified new SIDEWORLD Studio or Player production application deployment, and **no gameplay enablement**.

Further details: [Production deployment record](PLAYER_RUNTIME_PRODUCTION_DEPLOYMENT_2026_10_14.md). The earlier sections are preserved as a historical plan only.
