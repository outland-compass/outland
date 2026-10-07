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
