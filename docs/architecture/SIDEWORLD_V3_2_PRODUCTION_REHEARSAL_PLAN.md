# SIDEWORLD Schema V3.2 — Production Rehearsal Plan

Status: PRODUCTION PREPARED READ-ONLY; EXECUTE TOOLING CANDIDATE UNDER REVIEW / NO PRODUCTION EXECUTION AUTHORIZED
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

## Production Execute tooling review gate

Completed before the Execute-tooling PR:

1. Prepare-only tooling merged and CI-green;
2. production Prepare run completed with `PREPARED` on source SHA `3954929627c86cada3b7b4ed0233943f9a275b48`;
3. fresh production backup verified;
4. all nine preserved fingerprints matched the backup baseline;
5. production API rejected `universe`, `geo`, and `canon` as unexposed profiles (HTTP 406 / PGRST106);
6. dry-run listed exactly V3.2 migrations 0001..0004 in order;
7. independent read-only connector check still showed the 19-version baseline and no V3.2 objects.

Still required before any production Execute:

1. merge and CI-review the production Execute-tooling candidate;
2. review/static-validate the exact operator and recovery path;
3. define the short production quiet window and Compass write-pause procedure;
4. run another production Prepare at the exact Execute-tooling merge SHA;
5. obtain separate explicit founder approval naming that exact SHA.

Production Execute must remain atomic: all four wrapperless migrations under one outer psql -1 transaction, with 60s statement timeout, 5s lock timeout, committed-state verification before ledger repair, one-version-at-a-time ledger recording, deterministic CompleteLedger recovery, and post-apply fingerprint/API/ledger validation.

No production write is authorized by this document or by a successful Prepare.

## Execute-tooling candidate

`scripts/production/sideworld-v3-2/deploy-production-v3-2.ps1` is intended to mirror the already-proven staging operator with production-only target guards. It provides `Prepare`, `Execute`, and `CompleteLedger` modes. The presence or merge of this script does not authorize `Execute` or `CompleteLedger`; both require a separate explicit founder approval for the final merge SHA and the production quiet window.
