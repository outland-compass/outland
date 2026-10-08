# SIDEWORLD Studio V0-D2

Private SIDEWORLD authoring application.

V0-D2 extends the real authoring path across the V3.2 foundation:

- Universe;
- World and World ↔ City relationship;
- Theme;
- Franchise and Series;
- Character and Faction;
- Lore Facts and Canon Rules;
- Country and City truth.

All writes pass through validated server endpoints and narrow `SECURITY DEFINER` RPCs executable only by `service_role`. The browser receives neither private-schema access nor the service-role credential. `universe`, `geo` and `canon` remain outside Data API exposure and have no direct API-role USAGE.

The development fixture no longer pretends that BEYOND THE ATLAS is a Universe. BEYOND THE ATLAS remains the approved Franchise; its owning Universe must be chosen explicitly before real canon is seeded.

There is still no hard-delete flow. Production remains untouched.

## Runtime data source

Studio always reads canonical data from the configured Supabase backend. There is no runtime fixture/demo mode or `STUDIO_DATA_SOURCE` switch. Configure `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `STUDIO_UNIVERSE_SLUG` for the target deployment; missing configuration or an unknown universe fails explicitly instead of showing fabricated data. Keep fixture data only in automated tests. Production and preview/staging must use environment-specific Supabase credentials. Do not enable production authoring until its database RPC migrations, secrets, backup/restore readiness, and access controls are verified.
