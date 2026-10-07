# SIDEWORLD Studio V0-C — Private Read Boundary

**Status:** implementation candidate for review.  
**Production writes:** NOT AUTHORIZED.

## Decision

Do not grant browser/API roles direct access to `universe`, `geo` or `canon`.

Studio V0-C uses a narrow server-only RPC:

`public.sideworld_studio_read_model(p_universe_slug text)`

The function is visible through the already exposed `public` schema, but execution is granted only to `service_role`. The function itself is `SECURITY DEFINER` and reads the private authoring schemas with fully qualified relation names.

This preserves the V3.2 boundary:

- Data API schema list remains unchanged: `public`, `graphql_public`, `shared`, `land`.
- `universe`, `geo`, `canon` remain outside Data API exposure.
- `anon` and `authenticated` cannot execute the Studio RPC.
- `service_role` still has no direct USAGE on the private authoring schemas.
- the service-role credential exists only on the Studio server.

## Why not direct service_role grants?

A direct table-grant design would still require exposing the private schemas through PostgREST to make them addressable by a Supabase client. That would weaken the clean V3.2 boundary and enlarge the API surface.

The RPC approach keeps the private schemas private and exposes only the exact read contract required by Studio.

## Migration candidate

`supabase/migrations/202610070001_sideworld_studio_read_boundary.sql`

Properties:

- additive only;
- no table changes;
- no data backfill;
- no data seed;
- no RLS changes;
- no Data API config change;
- one read-only function;
- explicit privilege revocation/grant.

## Verification

`supabase/tests/verify-sideworld-studio-read-boundary.sql`

The test proves:

1. the RPC exists;
2. it is SECURITY DEFINER;
3. PUBLIC, anon and authenticated cannot execute it;
4. service_role can execute it;
5. private schemas still have no API-role USAGE;
6. service_role can invoke the RPC despite having no direct private-schema access.

Database CI runs this check in the clean replay and historical upgrade rehearsals.

## Rollback

`scripts/sideworld-studio/rollback-v0-c-read-boundary.sql`

Rollback only revokes execution and drops the RPC. No canonical data is touched.

## Application contract

Studio defaults to:

`STUDIO_DATA_SOURCE=fixture`

Only an explicitly configured server environment uses:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `STUDIO_UNIVERSE_SLUG`

The browser never receives the service-role key.

## Next gate

Before any staging apply:

1. Database CI must be green.
2. Studio CI must be green.
3. Review generated migration diff and grants.
4. Confirm no change to `supabase/config.toml` exposed schemas.
5. Prepare staging backup / fingerprint checks.
6. Obtain explicit authorization for staging write.

Production requires a separate approval after staging validation.
