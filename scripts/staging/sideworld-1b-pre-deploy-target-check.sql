-- SIDEWORLD Phase 1B pre-deployment target verification for outland-staging. READ ONLY: changes nothing.
-- Proves the connection is the expected staging database in the expected pre-deployment state.
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
  k text;
begin
  if current_setting('transaction_read_only') <> 'on' then raise exception 'not read-only'; end if;
  if (select count(*) from supabase_migrations.schema_migrations) <> 8
     or (select max(version) from supabase_migrations.schema_migrations) <> '202609030001' then
    raise exception 'Unexpected migration baseline: STOP (expected 8 versions ending 202609030001)';
  end if;
  if (select count(*) from land.candidates) <> 7 then raise exception 'Expected 7 candidates: STOP'; end if;
  for k in select jsonb_object_keys(expected_candidates) loop
    if (select md5(to_jsonb(c)::text) from land.candidates c where c.id = k::uuid) is distinct from expected_candidates ->> k then
      raise exception 'Candidate % differs from the rehearsed snapshot: STOP and take/re-rehearse a new backup', k;
    end if;
  end loop;
  if not exists (select 1 from shared.worlds where code = 'RIVERKEEPER')
     or exists (select 1 from shared.worlds where code = 'RAFTER')
     or (select count(*) from shared.worlds) <> 8 then
    raise exception 'World canon differs from the rehearsed snapshot: STOP';
  end if;
  if exists (select 1 from pg_namespace where nspname in ('universe', 'passport', 'infrastructure')) then
    raise exception 'universe/passport/infrastructure already exist: STOP';
  end if;
  raise notice 'TARGET VERIFIED: rehearsed staging baseline (8 versions, 7 candidates, legacy world canon)';
end $$;
rollback;
