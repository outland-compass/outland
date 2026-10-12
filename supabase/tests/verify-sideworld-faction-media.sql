begin;
do $$ begin
 if not (select relrowsecurity from pg_class where oid='canon.faction_visual_assets'::regclass) then raise exception 'Faction asset RLS disabled'; end if;
 if has_function_privilege('anon','public.sideworld_faction_media_gallery(text,text)','execute') or has_function_privilege('authenticated','public.sideworld_faction_media_gallery(text,text)','execute') then raise exception 'Browser role can access faction gallery'; end if;
 if not has_function_privilege('service_role','public.sideworld_faction_media_gallery(text,text)','execute') then raise exception 'Server gallery unavailable'; end if;
 if has_table_privilege('anon','canon.faction_visual_assets','select') or has_table_privilege('authenticated','canon.faction_visual_assets','select') then raise exception 'Asset table exposed'; end if;
 if not exists(select 1 from storage.buckets where id='sideworld-faction-media' and public=false) then raise exception 'Private faction bucket missing'; end if;
 if jsonb_array_length(public.sideworld_faction_media_gallery('invalid-universe','invalid-franchise')->'assets')<>0 then raise exception 'Gallery scope leakage'; end if;
end $$;
rollback;
