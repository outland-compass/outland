-- Studio-only authoring drafts. No player/publication access or canon writes.
create table canon.quest_drafts (
 id uuid primary key default gen_random_uuid(),
 universe_id uuid not null references universe.universes(id),
 franchise_id uuid not null references canon.franchises(id),
 series_id uuid not null references canon.series(id),
 city_id uuid not null references geo.cities(id),
 created_by uuid not null references auth.users(id),
 request_key uuid not null,
 input_snapshot jsonb not null check(jsonb_typeof(input_snapshot)='object'),
 status text not null default 'generating' check(status in ('generating','draft','failed')),
 revision integer not null default 0 check(revision>=0),
 model text,
 usage jsonb not null default '{}'::jsonb,
 error_code text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(created_by,request_key)
);
create index quest_drafts_scope_created on canon.quest_drafts(universe_id,franchise_id,series_id,city_id,created_at desc);
create table canon.quest_draft_revisions (
 draft_id uuid not null references canon.quest_drafts(id),
 revision integer not null check(revision>0),
 document jsonb not null check(jsonb_typeof(document)='object' and document->>'contractVersion'='1'),
 diagnostics jsonb not null check(jsonb_typeof(diagnostics)='array'),
 edited_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 primary key(draft_id,revision)
);
alter table canon.quest_drafts enable row level security;
alter table canon.quest_draft_revisions enable row level security;
revoke all on canon.quest_drafts,canon.quest_draft_revisions from public,anon,authenticated,service_role;

create function public.sideworld_quest_draft_begin(p_universe_slug text,p_franchise_slug text,p_series_slug text,p_city_slug text,p_actor uuid,p_request_key uuid,p_input_snapshot jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid; f uuid; s uuid; c uuid; d canon.quest_drafts; existing canon.quest_drafts;
begin
 if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN')) then raise exception 'Admin required'; end if;
 select id into u from universe.universes where slug=p_universe_slug and status<>'archived';
 select id into f from canon.franchises where universe_id=u and slug=p_franchise_slug and status='active';
 select id into s from canon.series where franchise_id=f and slug=p_series_slug and status<>'archived';
 select id into c from geo.cities where slug=p_city_slug and status<>'archived';
 if u is null or f is null or s is null or c is null then raise exception 'Invalid draft scope'; end if;
 if pg_column_size(p_input_snapshot)>250000 or jsonb_typeof(p_input_snapshot)<>'object' then raise exception 'Invalid input snapshot'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_actor::text,0));
 select * into existing from canon.quest_drafts where created_by=p_actor and request_key=p_request_key;
 if found then
   if existing.universe_id<>u or existing.franchise_id<>f or existing.series_id<>s or existing.city_id<>c or existing.input_snapshot->'brief' is distinct from p_input_snapshot->'brief' then raise exception 'Idempotency key belongs to different inputs'; end if;
   return jsonb_build_object('id',existing.id,'created',false,'status',existing.status);
 end if;
 if (select count(*) from canon.quest_drafts where created_by=p_actor and created_at>now()-interval '1 hour')>=10 then raise exception 'Hourly generation limit reached'; end if;
 if exists(select 1 from canon.quest_drafts where created_by=p_actor and status='generating' and created_at>now()-interval '3 minutes') then raise exception 'Generation already running'; end if;
 insert into canon.quest_drafts(universe_id,franchise_id,series_id,city_id,created_by,request_key,input_snapshot) values(u,f,s,c,p_actor,p_request_key,p_input_snapshot) returning * into d;
 return jsonb_build_object('id',d.id,'created',true,'status',d.status);
end $$;
create function public.sideworld_quest_draft_save(p_id uuid,p_actor uuid,p_expected_revision integer,p_document jsonb,p_diagnostics jsonb,p_model text,p_usage jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare d canon.quest_drafts; n integer;
begin
 if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN')) then raise exception 'Admin required'; end if;
 select * into d from canon.quest_drafts where id=p_id for update;
 if not found or d.status='failed' or d.revision<>p_expected_revision then raise exception 'Draft changed; refresh before saving'; end if;
 if pg_column_size(p_document)>250000 or jsonb_typeof(p_document)<>'object' or p_document->>'contractVersion' is distinct from '1' or jsonb_typeof(p_diagnostics)<>'array' then raise exception 'Invalid draft'; end if;
 if p_document->'scope'->>'universeId' is distinct from d.universe_id::text or p_document->'scope'->>'franchiseId' is distinct from d.franchise_id::text or p_document->'scope'->>'seriesId' is distinct from d.series_id::text or p_document->'scope'->>'cityId' is distinct from d.city_id::text then raise exception 'Scope mismatch'; end if;
 n:=d.revision+1;
 insert into canon.quest_draft_revisions(draft_id,revision,document,diagnostics,edited_by) values(d.id,n,p_document,p_diagnostics,p_actor);
 update canon.quest_drafts set status='draft',revision=n,model=coalesce(model,p_model),usage=case when d.revision=0 then p_usage else usage end,updated_at=now() where id=d.id;
 return n;
end $$;
create function public.sideworld_quest_draft_fail(p_id uuid,p_actor uuid,p_error_code text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN')) then raise exception 'Admin required'; end if;
 update canon.quest_drafts set status='failed',error_code=left(p_error_code,120),updated_at=now() where id=p_id and created_by=p_actor and status='generating';
end $$;
create function public.sideworld_quest_draft_list(p_universe_slug text,p_franchise_slug text,p_series_slug text,p_city_slug text)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(t),'[]'::jsonb) from (
 select d.id,d.status,d.revision,d.model,d.error_code,d.created_at,r.document->>'title' as title
 from canon.quest_drafts d join universe.universes u on u.id=d.universe_id join canon.franchises f on f.id=d.franchise_id join canon.series s on s.id=d.series_id join geo.cities c on c.id=d.city_id left join canon.quest_draft_revisions r on r.draft_id=d.id and r.revision=d.revision
 where u.slug=p_universe_slug and f.slug=p_franchise_slug and s.slug=p_series_slug and c.slug=p_city_slug order by d.created_at desc limit 30
 ) t;
$$;
create function public.sideworld_quest_draft_get(p_id uuid,p_universe_slug text,p_franchise_slug text,p_series_slug text,p_city_slug text)
returns jsonb language sql stable security definer set search_path='' as $$
 select to_jsonb(t) from (
 select d.*,r.document,r.diagnostics from canon.quest_drafts d join universe.universes u on u.id=d.universe_id join canon.franchises f on f.id=d.franchise_id join canon.series s on s.id=d.series_id join geo.cities c on c.id=d.city_id left join canon.quest_draft_revisions r on r.draft_id=d.id and r.revision=d.revision
 where d.id=p_id and u.slug=p_universe_slug and f.slug=p_franchise_slug and s.slug=p_series_slug and c.slug=p_city_slug
 ) t;
$$;
revoke all on function public.sideworld_quest_draft_begin(text,text,text,text,uuid,uuid,jsonb),public.sideworld_quest_draft_save(uuid,uuid,integer,jsonb,jsonb,text,jsonb),public.sideworld_quest_draft_fail(uuid,uuid,text),public.sideworld_quest_draft_list(text,text,text,text),public.sideworld_quest_draft_get(uuid,text,text,text,text) from public,anon,authenticated;
grant execute on function public.sideworld_quest_draft_begin(text,text,text,text,uuid,uuid,jsonb),public.sideworld_quest_draft_save(uuid,uuid,integer,jsonb,jsonb,text,jsonb),public.sideworld_quest_draft_fail(uuid,uuid,text),public.sideworld_quest_draft_list(text,text,text,text),public.sideworld_quest_draft_get(uuid,text,text,text,text) to service_role;
