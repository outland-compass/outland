# SIDEWORLD City Research Dossier persistence V1 — proposed migration

**Status:** code review only. **Not authorized or applied to production.**

## Current verified production
- Canonical `geo.cities` exists and has RLS enabled. Novi Sad is the only seeded city.
- Existing `geo.locations`, `geo.location_facts`, `geo.fact_sources`, `geo.sources` are all separate canonical records, with RLS enabled.
- Legacy `sideworld_studio_save_location` and `sideworld_studio_save_location_fact` perform `ON CONFLICT ... DO UPDATE`. They are **not** appropriate for AI discovery import.
- Current Studio research checkpoint survives only as an exportable local JSON file. No production city dossier table existed at audit.
- No duplicate universe, franchise, or city tables are permitted.

## New schema (only if explicitly approved)
One new `geo.city_research_dossiers` table, isolated from live quest and GEO datasets. Scope: `(city_id,owner_id,research_version)`, status partial/complete, optimistic revision, SHA-256 checksum, bounded 1.2 MB JSONB snapshot. No references to a franchise: this is research ONCE, reuse MANY times.

Service-only `public.sideworld_city_research_dossier_get_v1` and `public.sideworld_city_research_dossier_save_v1` RPCs. OWNER/ADMIN role check in SQL, actor-bound lookup, transaction lock and optimistic revision checking. Exact duplicate retries are idempotent, conflicting stale writes fail. No direct table access from anon/authenticated roles. Future Studio HTTP routes must additionally enforce the founder account, origin and feature flag, validate the full dossier contract and never accept a browser-supplied actor id.

## Required production release procedure (pending approval)
1. Verify `outland` migrations on current `main` match the deployed `supabase_migrations.schema_migrations` history, with unrelated draft migration PRs not applied.
2. Record production backup timestamp, verify recoverability and test restore or reliable isolated restore capability. On Free tier, verify the actual supported restore path rather than assuming PITR.
3. Rehearse on the existing optional staging environment because a service-role SECURITY DEFINER/RLS change is security-sensitive.
4. Apply only this additive migration when explicitly approved.
5. In a separate reviewed Studio deployment, enable the persistence-only feature flag after application and verify that one owner's city dossier cannot be read or overwritten from another actor.
6. Check PostgREST signatures, restart/reload its schema cache if needed, verify anonymous/authenticated execution denied and service-role RPC contract, exact idempotent retry, stale write conflict and no effect on existing OUTLAND/Player queries.
7. Leave the separately billed City Deep Research provider flag disabled until Tavily license/retention and a hard global search/Gateway budget have been approved.

## Rollback
Before first use, functions + table can be dropped in reverse dependency order. After first use, DO NOT drop the table: disable Studio persistence feature flag, retain/export snapshots, and keep the additive table inert pending repair. Roll back Studio deploy independently. Existing cities and quest data remain untouched.

## Copyright/data retention
A research dossier may contain third-party source excerpts. Confirm licensed storage/retention and cap stored excerpts before production activation. Quotations are evidence traces, not a grant to republish original text inside Player adventures.

## Tests to implement with companion Studio PR
- Unauthorized caller/origin and disabled-flag guard.
- Browser cannot send actor, role, city identity override, or raw SQL.
- Full validated query-key prefix, citation allowlist, 32-step maximum, fieldVerified/readyToImport remain false.
- Optimistic save and exact-key idempotent retry.
- No implicit research run or paid call from restoring saved dossier.
- No imported `geo.locations` or `geo.location_facts`; first field walk remains post-generation.
