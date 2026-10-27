# SIDEWORLD AI Location Assessments V1 — proposed rollout and rollback

> **Status: PROPOSAL ONLY.** PR review and green Web CI do not authorize a production database change.
> Never auto-apply this migration, enable scoring/persistence flags or trigger paid AI work as part of CI.

## Objective
Persist *franchise-specific AI editorial assessments*, not geography verification,
location permissions or quest releases, using existing canonical `geo.locations`
and `canon.franchises`. Each assessment is immutable for the tuple
(location, franchise, canon version, model version, rubric version, input fingerprint).
Models can be changed or rerun without overwriting historical decisions.

## Pre-change audit (read-only, 2026-10-27)
- Production project: `huzcukdovavejejwohey`; optional staging: `clgpxvyflycudzhdzjlv`.
- Production: 19 Novi Sad locations, 63 sourced facts, 34 references; 11 canonical franchises.
- `geo.locations`, `geo.location_facts`, `geo.sources`, `geo.fact_sources`,
  `canon.franchises` all have RLS enabled. Neither `service_role` nor
  `authenticated` can select those tables directly.
- All existing Studio City Knowledge reads go via scoped security-definer RPCs,
  and the location-media V1 migrations establish a server-only service-role RPC pattern.
- `shared.user_roles` has an OWNER identity; proposed storage RPC checks OWNER/ADMIN.
- Latest verified production migration version before this proposal:
  `20261019063001_sideworld_location_reference_media_v1`.
- No `geo.location_assessments` table is currently deployed.
- Relevant current code: `sideworld_studio` location-scoring V1 contract,
  founder-only scoring preview, scored route selection and one-click quest preview.
  Player and OUTLAND public APIs do not use the new assessment table.

## Explicit approval gate
Before execution in production obtain **separate founder approval**, verify
a fresh backup AND restoration readiness (not merely backup existence), check
migration divergence, apply locally/staging when useful, and review the
exact migration/CI head SHA. Use an additive migration in the OUTLAND repo.
Do not conflate this approval with authorization to activate paid AI scoring
or multiplayer.

## Post-approval execution sequence
1. Run local DB reset/test migration against the repo's exact migration tree;
   inspect roles, indexes, foreign keys, RLS grants and execution permissions.
2. Check production and (if used) staging migration inventory, backup and
   restore readiness. Capture baseline row counts and privileges.
3. Apply **only** `20261027150000_sideworld_location_assessments_v1.sql` via
   the approved migration workflow.
4. Use the companion read-only verification script to confirm table,
   immutable uniqueness, restricted EXECUTE grants and RLS.
5. Run an authenticated Studio owner-only *nonpaid* test read. Require
   explicit separate authorization before writing the first real AI score.
6. Monitor RPC failures, query cost, assessment counts and access grants;
   all new Studio persistence code remains separately feature gated.

## Rollback
The migration is additive and does not alter existing geo/canon/player tables.
Disable the scoring persistence feature flag first and confirm that no current
application depends on the new read RPC. Back up any created assessments
before destructive rollback. An explicitly authorized rollback migration is:

```sql
begin;
revoke execute on function public.sideworld_location_assessment_record_v1(
  uuid,uuid,uuid,integer,text,text,text,jsonb,numeric,jsonb,jsonb,boolean
) from service_role;
revoke execute on function public.sideworld_location_assessments_for_city_v1(
  uuid,uuid,text,text
) from service_role;
drop function if exists public.sideworld_location_assessment_record_v1(
  uuid,uuid,uuid,integer,text,text,text,jsonb,numeric,jsonb,jsonb,boolean
);
drop function if exists public.sideworld_location_assessments_for_city_v1(
  uuid,uuid,text,text
);
drop table if exists geo.location_assessments;
commit;
```

**Destructive rollback requires its own approval and backup of scored records.**
For functional rollback without data loss, leave the additive table in place
and simply disable the feature flags and revoke RPC EXECUTE as required.

## Security boundaries
- No direct grants to end-user JWTs, and no public read policy.
- Only the service-role **RPC** can read/write; protected Studio server code
  must revalidate session identity and canonical scope before calling it.
- Write function checks the actual owner/admin actor, franchise canon version,
  location identity, 5 scoring dimensions, bounded confidence, risk flags and
  restricted/unsafe route eligibility.
- Scores are never evidence of a field visit, a permit, a resolved puzzle or
  an approved/publicly playable release.
- Source IDs and model rationales MUST be checked against the live
  City Knowledge manifest by the Studio scoring contract before storage;
  the table is not a substitute for independent field QA.
