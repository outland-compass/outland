-- Static read-only assertions for the private cross-quest location evidence boundary.
begin;
do $$
declare bucket record;
begin
  if to_regclass('geo.location_media') is null then raise exception 'location media table missing'; end if;
  if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='geo' and c.relname='location_media' and c.relrowsecurity)
    then raise exception 'location media RLS must be enabled'; end if;
  if has_table_privilege('anon','geo.location_media','SELECT') or
     has_table_privilege('authenticated','geo.location_media','SELECT') or
     has_table_privilege('authenticated','geo.location_media','INSERT') or
     has_table_privilege('authenticated','geo.location_media','UPDATE')
    then raise exception 'browser roles must not access private location media'; end if;
  if not has_table_privilege('service_role','geo.location_media','SELECT')
    then raise exception 'server read boundary missing'; end if;
  if has_function_privilege('anon','public.sideworld_location_media_list(uuid)','EXECUTE') or
     has_function_privilege('authenticated','public.sideworld_location_media_list(uuid)','EXECUTE') or
     has_function_privilege('authenticated','public.sideworld_location_media_private(uuid)','EXECUTE') or
     has_function_privilege('authenticated','public.sideworld_location_media_register(uuid,uuid,text,text,text,integer,text,text,text,text,text,uuid)','EXECUTE') or
     has_function_privilege('authenticated','public.sideworld_location_media_review(uuid,uuid,text,text,boolean)','EXECUTE')
    then raise exception 'private location media RPC exposed to browser'; end if;
  if not has_function_privilege('service_role','public.sideworld_location_media_list(uuid)','EXECUTE')
    then raise exception 'service-only RPC grant missing'; end if;
  select * into bucket from storage.buckets where id='sideworld-location-media';
  if not found or bucket.public or bucket.file_size_limit<>10485760
     or not (bucket.allowed_mime_types @> array['image/jpeg','image/png','image/webp']::text[])
    then raise exception 'private location media bucket policy mismatch'; end if;
  if not exists(select 1 from pg_constraint where conrelid='geo.location_media'::regclass
     and conname='location_media_ai_approval') then raise exception 'AI rights check missing'; end if;
  if not exists(select 1 from pg_indexes where schemaname='geo' and tablename='location_media'
     and indexname='location_media_one_verified_primary_idx') then raise exception 'single approved primary missing'; end if;
  raise notice 'PASS: private location reference media RLS, scope, bucket and rights gates';
end $$;
rollback;
