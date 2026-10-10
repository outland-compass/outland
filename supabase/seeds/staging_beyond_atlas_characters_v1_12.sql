-- Staging-only idempotent Character Bible V1.12 draft seed.
-- Never execute in production without a separate content import approval.
-- Canonical character identities stay in canon.characters.
do $$
declare
  v_franchise uuid;
begin
  select f.id into v_franchise
  from canon.franchises f join universe.universes u on u.id = f.universe_id
  where f.slug = 'beyond-the-atlas' and u.slug = 'the-uncharted';
  if v_franchise is null then
    raise exception 'Beyond the Atlas franchise in THE UNCHARTED not found';
  end if;
  insert into canon.characters (franchise_id,slug,name,role,canon_status)
  select v_franchise, x.slug, x.name, x.role, 'draft'
  from (values
    ('damien-wayne','Damien Wayne','Explorer / Warrior of Light'),
    ('audrey-quin','Audrey Quin','Adventurer / English teacher'),
    ('iris-wayne','Iris Wayne','Artist'),
    ('omar','Omar','Remote IT ally'),
    ('amon-dimano','Amon Dimano','Deceased Teacher'),
    ('maria','Maria','Messenger'),
    ('maya','Maya','Apprentice'),
    ('z','Z','Director')
  ) as x(slug,name,role)
  where not exists (
    select 1 from canon.characters c where c.franchise_id = v_franchise and c.slug = x.slug
  );
end $$;
