# SIDEWORLD DNA Metadata Status RPC V1 — Proposed Security Change

**Review-only SQL, NOT a production migration.** Neither accompanying .sql
file in docs/architecture is executed by a GitHub merge or by Supabase
migration replay. Create a genuine versioned migration using Supabase CLI only
after explicitly approving this database change.

## Audit foundation (26 October 2026)

- Production DB project: outland (production). No production SQL writes
  or migrations were performed for this proposal.
- Canonical tables already exist at universe.universes and canon.franchises,
  both RLS-enabled. Their metadata columns are JSONB and contain existing
  approved content, including sealed long-arc story details.
- Studio private read RPC deliberately excludes all metadata and only
  exposes canonical scope, characters and canon rules. Its guarded root writer
  does NOT accept a general metadata patch.
- Current live catalog: 5 universes, 11 franchises, with no approved
  experience_dna_v1 reserved metadata namespace. Eight newer franchises
  contain only initial visual/gameplay concept metadata.
- Existing approvals are heterogeneous and should NOT be mapped to
  effective Visual/Gameplay DNA by naive JSONB key presence.

## Proposed minimal, secret-safe database contract

RPC: public.sideworld_studio_dna_metadata_status_v1(p_universe_slug text),
returns JSONB with exactly these fields:
  schemaVersion (integer 1);
  universeId (UUID string);
  universeSlug (slug);
  rows (array, one row per universe franchise).

Each row has exactly:
  franchiseId (UUID);
  franchiseSlug (slug);
  canonVersion (integer);
  dnaNamespaceState ('absent' | 'object' | 'malformed');
  profileVersion (strict numeric dotted version or null).

Raw JSONB, Bibles, sealed plot documents, character biographies, images,
hashes derived from full secret metadata, and unrelated metadata keys
are NEVER returned.

Security: SECURITY DEFINER with qualified private relations and pinned
search_path, explicit same-transaction EXECUTE revocation from PUBLIC,
anon, authenticated; service_role only. Safe default: unknown universe
returns null and Studio rejects it.

## Matching Studio adapter

Studio PR #190 implements:
- server-only key access, off by default when
  SIDEWORLD_DNA_METADATA_READ_V1_ENABLED is absent;
- exact shape checking, canonical UUID/version and row-cardinality parity;
- fail-closed unknown RPC/mismatched data;
- editorial-only results, no import/generation/release permission.

**Do not set the flag until the database function is authorized,
deployed, and tested against an isolated environment.**

## Required next steps to request production authorization

1. Open a dedicated actual OUTLAND migration PR using the Supabase CLI to
   create a versioned migration; copy SQL proposal after review.
2. Attach rollback-only local SQL security tests to database-ci.yml's
   disposable local DB job. Require all checks to pass.
3. Verify backups and restore readiness and current migrated ledger state
   before any production SQL application; stage on demand.
4. Audit service-role, PUBLIC, anon, authenticated execution privileges,
   RLS boundaries, exposure configuration and cross-universe results.
5. Request explicit founder approval for the named migration.
6. Apply migration through established controlled procedure; verify
   schema, grants, end-to-end Studio admin response, no sealed leaks.
7. Enable Studio flag and deploy separately.
8. Only after complete source reconciliation design a distinct audited
   compare-and-swap metadata-write RPC and editorial approval UI.

## Rollback

First disable Studio read feature flag and redeploy or restore previous
Studio version. In a separately authorized SQL change, drop the function
after checking dependencies. No canonical table, franchise ID, RLS
policy, quest release, OUTLAND app or Player flag needs changing.

**In this PR no database schema, privileges, data or migration history are
changed.** The SQL files are readable proposals only.
