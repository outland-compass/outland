-- Preserve the verified Caraworld hero image in the source snapshot shape already consumed by Compass.
update land.candidate_sources
set source_snapshot = source_snapshot || jsonb_build_object(
  'raw_payload', jsonb_build_object(
    'image_url', 'https://cdn.caraworld.com/bilder/i/028/130/811/28130811-3-728-0.webp'
  )
)
where source_url = 'https://www.caraworld.de/wohnmobile/poessl/summit/28130718/poessl-summit-600-plus-gepflegt-aus-1-hand.html';
