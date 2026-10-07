# SIDEWORLD Studio V0-D3

Private SIDEWORLD authoring application.

V0-D3 completes the authoring/read surface needed before **Canon Context Builder V0**:

- Universe, Worlds and Themes;
- Franchise and Series;
- Characters with structured identity/personality/knowledge/voice/visual/AI profiles;
- Character relationships with phase validity;
- Factions;
- Lore Facts and Canon Rules;
- Country, City and World ↔ City mapping;
- deterministic server read model exposing Worlds, Themes and Relationships.

All private writes remain behind validated server endpoints and `service_role`-only SECURITY DEFINER RPCs. The private `universe`, `geo` and `canon` schemas remain outside Data API exposure.

**Important canon gate:** BEYOND THE ATLAS is a Franchise. Its owning Universe has not yet been approved, so Studio must not seed real canonical BEYOND THE ATLAS data until that parent is chosen.

Production remains untouched.
