# SIDEWORLD Studio V0-B

Private SIDEWORLD authoring application.

V0-B adds a typed, server-only read contract and a Canon Inspector backed by a **non-production development fixture**. It intentionally contains **no production database grants, no production database reads, and no authoring writes**.

The fixture mirrors the V3.2 authoring concepts needed for the next security-reviewed slice: Universe, Franchise, Series, Characters, Factions, Lore, Canon Rules and City.

Current boundaries:

- no service-role credential in the app;
- no connection to private `universe`, `geo` or `canon` schemas;
- no production seed;
- no CRUD;
- no AI mutation;
- no player/quest runtime.

The next slice is the reviewed server-side private-schema read boundary and its additive access migration. That migration requires separate review before staging or production execution.
