-- SIDEWORLD Phase 1B checkpoint between Phase A (8 historical migrations) and Phase B (2 SIDEWORLD
-- migrations). READ ONLY. Confirms the conditions the legacy backfill requires; any failure = do NOT run Phase B.
\set ON_ERROR_STOP 1
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;
do $$
begin
  if (select count(*) from supabase_migrations.schema_migrations) <> 16
     or (select max(version) from supabase_migrations.schema_migrations) <> '20260919100334'
     or exists (select 1 from supabase_migrations.schema_migrations where version like '2026100200%') then
    raise exception 'Phase A ledger unexpected: STOP (expected 16 versions ending 20260919100334, no SIDEWORLD)';
  end if;
  if exists (select 1 from universe.nodes where node_type <> 'stay') then
    raise exception 'Non-stay legacy universe node present: STOP (backfill would abort)';
  end if;
  if exists (select 1 from universe.frontiers) or exists (select 1 from universe.spots) then
    raise exception 'Legacy frontiers/spots present: STOP (backfill would abort)';
  end if;
  if to_regnamespace('infrastructure') is not null then
    raise exception 'infrastructure schema already exists: STOP';
  end if;
  raise notice 'CHECKPOINT PASSED: 16 versions, % stay node(s), no frontiers/spots - Phase B may proceed',
    (select count(*) from universe.nodes);
end $$;
rollback;
