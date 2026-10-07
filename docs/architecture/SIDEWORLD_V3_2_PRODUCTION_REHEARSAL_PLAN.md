# SIDEWORLD Schema V3.2 — Production Rehearsal Plan

Status: PREPARE TOOLING ONLY / NO PRODUCTION WRITE PATH
Production target: huzcukdovavejejwohey
Staging ref clgpxvyflycudzhdzjlv is explicitly rejected by production tooling.
Approved source baseline before this tooling branch: 50ae523eb1b2f5806eade62f6a62d5cde356592a.

## Verified production baseline (read-only, 2026-10-07)

- migration ledger: 19 versions, latest 20261004140102;
- legacy universe.nodes/frontiers/spots absent;
- V3.2 universe.universes, geo.countries, canon.franchises absent;
- universe.set_updated_at() retained;
- Passport journey trigger still uses that helper;
- shared.worlds contains 8 rows and production canon includes RAFTER, with no RIVERKEEPER;
- land.candidates 20 rows;
- shared.activities 232 rows;
- infrastructure.bases 1 row;
- passport.journeys/events 0 rows.

These counts are observational only. The authoritative preservation evidence for a future deployment is the fresh production backup plus fingerprints generated immediately before it.

## Prepare-only tooling

The production tooling intentionally exposes no Execute mode.

scripts/production/sideworld-v3-2/prepare-production-v3-2.ps1 performs only:

1. exact clean/unlinked checkout and explicit SourceSha gate;
2. exact four migration blob checks;
3. feature-commit and Database CI ancestry check;
4. production-only DB session, with staging ref rejected;
5. fresh production roles/schema/data/custom dump;
6. offline backup verification;
7. production-specific read-only preflight: RAFTER identity, exact 19-version ledger, no V3.2 objects;
8. fresh preserved-data and privilege fingerprints and equality against the backup baseline;
9. PostgREST exposure probe requiring universe/geo/canon to be rejected as unexposed schemas (HTTP 406 / PGRST106), without depending on brittle error-message wording or schema ordering;
10. migration-list check;
11. db push --dry-run requiring exactly 202610060001..0004 in order.

A successful result must be:

PREPARED - production read-only checks passed, no production changes

## Before any production Execute tooling is created

Required:

1. merge and CI-review this Prepare-only tooling;
2. run it against production and review complete evidence;
3. confirm fresh backup integrity and preserved fingerprints;
4. independently re-check production baseline through the Supabase connector;
5. define the production quiet window and Compass write-pause procedure;
6. prepare a separate production Execute operator by adapting the proven staging atomic path;
7. review and locally/static validate that operator;
8. run another production Prepare at the exact Execute-tooling merge SHA;
9. obtain separate explicit founder approval naming that exact SHA.

Production Execute must remain atomic: all four wrapperless migrations under one outer psql -1 transaction, with 60s statement timeout, 5s lock timeout, committed-state verification before ledger repair, one-version-at-a-time ledger recording, deterministic CompleteLedger recovery, and post-apply fingerprint/API/ledger validation.

No production write is authorized by this document or by a successful Prepare.