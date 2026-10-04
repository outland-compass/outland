-- SIDEWORLD Phase 1B post-deployment validation for outland-staging. READ ONLY: changes nothing.
\set ON_ERROR_STOP 1
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;
do $$
declare
  expected_candidates constant jsonb := '{
    "4ae0bac7-3e53-45f2-9a45-6a2cca8e81f6": "652f1c8a32bfbf402d72a8bcca794e79",
    "7a740883-7d0e-400b-b753-2dd6486c9fe8": "43334e9e3cb9c91fce55fc3359547d7c",
    "9fcd4057-90c2-4ad0-a3d1-3e5560c74eee": "5aa7f341c6ae713fcf6d3ea9c74d4a1b",
    "a1df1c88-4a6a-48fe-bae5-b06e89f6ecc0": "bfb1290898892f1cb5e1967cef32c89d",
    "b9510a64-e94c-412d-ba04-7a574411e58f": "69d1941d7431399b8fa0dfac98e3e6a6",
    "df36ab39-6d3b-4147-801d-7fdb1c77b01b": "a732dde9a9e495c0236135a3439910b7",
    "fb315874-e63f-42eb-bd28-8d06e8b93fbe": "b52efec7994e3d093fa8ba48a5646dba"}';
  expected_world constant uuid := 'edbd3bf4-45e7-4a38-9b3c-0455a0627fb7'; -- OUTLAND_WORK
  expected_versions constant text[] := array['20260912141712','20260912141742','20260912145301','20260913141314',
    '20260913141954','20260917110721','202609190001','20260919100334','202610020001','202610020002'];
  k text; v_missing text[];
begin
  -- 1. Migration ledger: baseline 8 + exactly these 10.
  select array_agg(e) into v_missing from unnest(expected_versions) e
   where not exists (select 1 from supabase_migrations.schema_migrations m where m.version = e);
  if v_missing is not null then raise exception 'Missing migration versions: %', v_missing; end if;
  if (select count(*) from supabase_migrations.schema_migrations) <> 18 then
    raise exception 'Expected 18 recorded migrations, found %', (select count(*) from supabase_migrations.schema_migrations);
  end if;
  -- 2. The seven pre-existing candidates: present, same world, original values unchanged
  --    (hash excludes only development_model, added with default by 20260917110721_pod_radar).
  for k in select jsonb_object_keys(expected_candidates) loop
    if not exists (select 1 from land.candidates c where c.id = k::uuid) then
      raise exception 'Candidate % missing', k; end if;
    if (select world_id from land.candidates where id = k::uuid) is distinct from expected_world then
      raise exception 'Candidate % world link changed', k; end if;
    if (select md5((to_jsonb(c) - 'development_model')::text) from land.candidates c where c.id = k::uuid)
       <> expected_candidates ->> k then
      raise exception 'Candidate % original values changed', k; end if;
  end loop;
  -- 3. World identities: no duplicate floating canon, legacy records intact.
  if (select count(*) from shared.worlds where asset_kind = 'FLOATING' and environment = 'River'
      and archetype = 'GUARDIAN' and inner_movement = 'FLOW') <> 1 then
    raise exception 'Floating world identity is missing or duplicated';
  end if;
  if not exists (select 1 from shared.worlds where id = expected_world and code = 'OUTLAND_WORK') then
    raise exception 'OUTLAND_WORK world identity changed'; end if;
  -- 4. SIDEWORLD bases: parity with every legacy stay node, exact audit provenance.
  if (select count(*) from infrastructure.bases) <> (select count(*) from universe.nodes where node_type = 'stay')
     or (select count(*) from infrastructure.base_legacy_migration_audit) <> (select count(*) from universe.nodes where node_type = 'stay') then
    raise exception 'Base/audit/stay counts differ'; end if;
  if exists (select 1 from universe.nodes n
             left join infrastructure.base_legacy_migration_audit a on a.source_table = 'universe.nodes' and a.source_id = n.id
             left join infrastructure.bases b on b.id = a.base_id
             where n.node_type = 'stay' and (b.id is null or a.source_snapshot is distinct from to_jsonb(n)
               or (b.world_id, b.asset_id, b.name, b.status, b.metadata, b.created_at, b.updated_at)
                  is distinct from (n.world_id, n.asset_id, n.name, n.status, n.metadata, n.created_at, n.updated_at))) then
    raise exception 'Base parity or audit provenance failure'; end if;
  -- 5. RLS deny-by-default on the private infrastructure schema.
  if (select count(*) from pg_class c join pg_namespace s on s.oid = c.relnamespace
      where s.nspname = 'infrastructure' and c.relkind = 'r' and c.relrowsecurity) <> 2 then
    raise exception 'RLS missing on infrastructure tables'; end if;
  if has_schema_privilege('anon', 'infrastructure', 'USAGE') or has_schema_privilege('authenticated', 'infrastructure', 'USAGE')
     or has_table_privilege('anon', 'infrastructure.bases', 'SELECT') or has_table_privilege('authenticated', 'infrastructure.bases', 'SELECT') then
    raise exception 'infrastructure is exposed to client roles'; end if;
  raise notice 'POST-DEPLOY VALIDATION PASSED: 18 versions, 7/7 candidates unchanged, % base(s) with exact audit, RLS deny-by-default',
    (select count(*) from infrastructure.bases);
end $$;
rollback;
