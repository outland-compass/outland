-- Preserve the high-priority Poseljani / Skadar Lake discovery signal captured in production.
insert into land.signals (
  status,source_name,source_url,raw_title,raw_description,raw_location,
  raw_price,raw_currency,raw_area_m2,raw_payload,extracted_payload,
  extraction_status,last_seen_at
)
select
  'NEW','Dom Home Montenegro','https://www.dom-home.me/me/details/1562/?utm_source=chatgpt.com',
  'Poseljani / Skadar Lake — stream and old mills',
  'High-interest OUTLAND POD discovery signal because of the stream, old mills and direct Skadar Lake relationship. Requires forensic DD for exact parcel, ownership, legal access, protected-area/planning constraints and legal POD/rural-tourism development path.',
  'Poseljani / Skadar Lake, Montenegro',60000,'EUR',2575,
  '{"discovery_hunt":"MONTENEGRO_POD_LAND","user_priority":"HIGH","distinctive_features":["stream","old mills","Skadar Lake relationship"],"source_claims_to_verify":["1/1 ownership","direct lake relationship"]}'::jsonb,
  '{"development_model":"POD","search_profile_code":"MONTENEGRO_POD_LAND","priority_reason":"stream + mill + water landscape","gate_status":"UNVERIFIED"}'::jsonb,
  'MANUAL_REVIEW_REQUIRED',now()
where not exists (
  select 1 from land.signals where source_url like '%dom-home.me/me/details/1562%'
);
