-- SIDEWORLD Location Intelligence V3: production PRE-migration diagnostic.
-- READ ONLY. No DDL, DML, service keys, dumped contents, or data mutation.
-- Run against the actual canonical OUTLAND production project immediately before
-- a separately authorized application of migration 20261028101500.
-- This diagnostic is NOT migration approval or a replacement for restore proof.
--
-- PASS criteria intentionally do not pin exact population counts: new research
-- is allowed. Keep an independently recorded preflight baseline for postflight.
WITH research AS (
  SELECT f.*
  FROM geo.location_facts f
  JOIN geo.cities c ON c.id = f.city_id
  WHERE c.slug = 'novi-sad'
    AND c.country_code = 'RS'
    AND f.fact_type = 'research_candidate'
    AND f.metadata ? 'location_master_v3'
    AND f.metadata ? 'original_v2_record'
),
all_v3_facts AS (
  SELECT f.*
  FROM geo.location_facts f
  JOIN geo.cities c ON c.id = f.city_id
  WHERE c.slug = 'novi-sad'
    AND c.country_code = 'RS'
    AND f.fact_type = 'research_candidate'
    AND f.metadata ? 'location_master_v3'
),
franchise_fit_slugs AS (
  SELECT r.id, slug.value AS franchise_slug
  FROM research r
  CROSS JOIN LATERAL jsonb_array_elements_text(
    CASE WHEN jsonb_typeof(r.metadata->'franchise_fit_hypotheses') = 'array'
      THEN r.metadata->'franchise_fit_hypotheses'
      ELSE '[]'::jsonb
    END
  ) AS slug(value)
),
v3_tables(schema_name, table_name) AS (
  VALUES
    ('geo','location_research_candidates'),
    ('geo','location_hierarchy'),
    ('geo','location_clues'),
    ('canon','location_franchise_fits'),
    ('canon','location_character_uses'),
    ('canon','location_clue_uses')
),
numbers AS (
  SELECT
    (SELECT count(*) FROM geo.locations) AS locations,
    (SELECT count(*) FROM canon.quest_releases) AS releases,
    (SELECT count(*) FROM research) AS research_count,
    (SELECT count(*) FROM all_v3_facts) AS source_v3_count,
    (SELECT count(*) FROM research r
      LEFT JOIN geo.locations l ON l.id = r.location_id
      WHERE l.id IS NULL OR l.city_id <> r.city_id) AS bad_location_links,
    (SELECT count(*) FROM research
      WHERE nullif(metadata->>'candidate_id','') IS NULL) AS missing_external_ids,
    (SELECT count(*) FROM research
      WHERE jsonb_typeof(metadata->'original_v2_record') IS DISTINCT FROM 'object'
        OR jsonb_typeof(metadata->'location_master_v3'->'record') IS DISTINCT FROM 'object') AS malformed_payloads,
    (SELECT count(*) FROM (
      SELECT city_id, metadata->>'candidate_id'
      FROM research
      GROUP BY city_id,metadata->>'candidate_id'
      HAVING count(*) > 1
    ) duplicates) AS duplicate_external_ids,
    (SELECT count(*) FROM franchise_fit_slugs ff
      WHERE (SELECT count(*) FROM canon.franchises c WHERE c.slug = ff.franchise_slug) <> 1
    ) AS ambiguous_franchises,
    (SELECT count(*) FROM v3_tables v JOIN information_schema.tables t
      ON t.table_schema = v.schema_name AND t.table_name = v.table_name) AS existing_v3_tables,
    (SELECT count(*) FROM information_schema.columns
      WHERE table_schema='geo' AND table_name='fact_sources'
        AND column_name IN ('source_locator','source_excerpt','observed_at')) AS existing_v3_columns,
    (SELECT count(*) FROM pg_class c
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname IN ('geo','canon') AND c.relkind IN ('r','p')
        AND NOT c.relrowsecurity) AS rls_disabled_tables,
    (SELECT count(*) FROM pg_class c
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname IN ('geo','canon') AND c.relkind IN ('r','p')
        AND (has_table_privilege('anon',c.oid,'SELECT')
          OR has_table_privilege('authenticated',c.oid,'SELECT'))) AS directly_exposed_tables,
    (SELECT count(*) FROM supabase_migrations.schema_migrations
      WHERE version='20261028101500') AS applied_v3_migration
),
checks AS (
  SELECT 'pre_migration_history_absent' AS check_name,
    applied_v3_migration = 0 AS passed, applied_v3_migration::text AS observed FROM numbers
  UNION ALL SELECT 'no_partial_v3_tables', existing_v3_tables = 0,
    existing_v3_tables::text FROM numbers
  UNION ALL SELECT 'no_partial_provenance_columns', existing_v3_columns = 0,
    existing_v3_columns::text FROM numbers
  UNION ALL SELECT 'novi_sad_v3_records_have_v2', source_v3_count = research_count AND research_count > 0,
    research_count::text || '/' || source_v3_count::text FROM numbers
  UNION ALL SELECT 'all_original_payloads_are_objects', malformed_payloads = 0,
    malformed_payloads::text FROM numbers
  UNION ALL SELECT 'all_research_records_link_to_same_city_location', bad_location_links = 0,
    bad_location_links::text FROM numbers
  UNION ALL SELECT 'all_candidate_ids_present', missing_external_ids = 0,
    missing_external_ids::text FROM numbers
  UNION ALL SELECT 'no_duplicate_city_candidate_ids', duplicate_external_ids = 0,
    duplicate_external_ids::text FROM numbers
  UNION ALL SELECT 'franchise_hypotheses_resolve_uniquely', ambiguous_franchises = 0,
    ambiguous_franchises::text FROM numbers
  UNION ALL SELECT 'existing_geo_canon_rls_enabled', rls_disabled_tables = 0,
    rls_disabled_tables::text FROM numbers
  UNION ALL SELECT 'no_direct_player_select_on_geo_canon', directly_exposed_tables = 0,
    directly_exposed_tables::text FROM numbers
  UNION ALL SELECT 'no_direct_player_schema_usage',
    NOT (has_schema_privilege('anon','geo','USAGE')
      OR has_schema_privilege('authenticated','geo','USAGE')
      OR has_schema_privilege('anon','canon','USAGE')
      OR has_schema_privilege('authenticated','canon','USAGE')),
    'private schema privileges' FROM numbers
),
report AS (
  SELECT check_name, CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS status, observed
  FROM checks
  UNION ALL SELECT 'OVERALL', CASE WHEN bool_and(passed) THEN 'GO_FOR_APPROVAL_ONLY' ELSE 'NO_GO' END,
    count(*)::text || ' checks; authorization still required' FROM checks
  UNION ALL SELECT 'BASELINE_LOCATIONS', 'INFO', locations::text FROM numbers
  UNION ALL SELECT 'BASELINE_RESEARCH', 'INFO', research_count::text FROM numbers
  UNION ALL SELECT 'BASELINE_QUEST_RELEASES', 'INFO', releases::text FROM numbers
)
SELECT check_name, status, observed
FROM report
ORDER BY CASE WHEN check_name = 'OVERALL' THEN 0
              WHEN status = 'FAIL' THEN 1
              WHEN status = 'PASS' THEN 2
              ELSE 3 END, check_name;
