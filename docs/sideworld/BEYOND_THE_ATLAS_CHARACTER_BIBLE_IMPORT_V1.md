# Beyond the Atlas — Character Bible V1.12 Import Plan

**Status:** Source reconciliation and import mapping; no database writes or media upload.
**Primary source:** `SIDEWORLD_Beyond_the_Atlas_Character_Bible_V1_12.docx` (5 October 2026), user-authored Word document. Do not substitute earlier V1–V1.8 versions.
**Hierarchy:** SIDEWORLD platform → THE UNCHARTED universe (verify canonical ID before import) → Beyond the Atlas franchise → The Lost Cartographers series. Timekeepers remains future direction. The Unbroken Line is the overarching mystery, not a season. SIGNAL is a gameplay trigger.

## Canonical characters and visual direction

| Canonical key (proposed slug) | Role | Visual continuity | Source status |
|---|---|---|---|
| `damien-wayne` | Explorer / Warrior of Light, 51 | Salt-and-pepper hair, short beard, practical travel clothing | Approved character identity; current visual direction |
| `audrey-quin` | Adventurer / English teacher, 33 | Fair complexion, long dark ponytail, glasses, elegant practical explorer wardrobe | Latest portrait is current visual reference |
| `iris-wayne` | Artist / Damien's daughter, 13 | Lighter hair with bangs, blue-green eyes, sketchbook, delicate silver jewelry | Updated visual identity approved |
| `omar` | Remote IT expert / digital nomad | Short slim build, very short dark hair, short beard, cap, original sci-fi T-shirts | First name approved; family name `Al-Noor` provisional |
| `amon-dimano` | Deceased Teacher / Damien's mentor | Long silver-gray hair and beard, round metal glasses, old-fashioned deep-red-stone ring | Approved visual direction; do not assert supernatural ring powers |
| `maria` | Messenger / Order of Light | Silver-gray hair, dark rectangular glasses, white high-collar blouse, black skirt, pale blue shawl | Approved visual direction |
| `maya` | Apprentice / Order of Light | Long dark braids, decorative accents, richly embroidered dark blue/green/red/gold clothes, ancient book | **Use user-supplied reference image** |
| `z` | Director / antagonist | Bald, pale skin, piercing blue eyes, formal black suit, white shirt, black tie | **Existing portrait canonical: never redesign or replace face** |

Luna is Iris's recurring small white Bolognese dog and must have consistent visual continuity, but is **not automatically a human `canon.characters` record**; decide the canonical companion representation after inspecting data dependencies.

The Black Circle, Directorate and Black Agents are factions/collectives, not automatically individual character records. All members of this adversarial structure are male per current source canon. Order of Light is the benevolent faction, with Teachers, Seers and Warriors.

## Required importer behavior

1. Register the Word document as a **versioned source** with checksum, provenance, import timestamp and supersession link; preserve embedded images as original references with hashes.
2. Extract text and embedded media without generating new portraits. Attach images only where document context reliably identifies their subject; ambiguous mappings require editorial review.
3. Resolve canonical franchise and character IDs by slug **within the franchise**, with human approval before any writes. Do not create a second universe/franchise or migrate older character names automatically.
4. Map character biography and role to existing `canon.characters` fields. Map personality, voice, identity, knowledge, visual rules and AI constraints to existing JSONB profiles only after auditing the live read/write RPC contract.
5. Use the V1.12 approved visual direction and original image as the source of truth. Store immutable approved reference asset versions and usage rights in a future audited media design; `shared.assets` is a physical-asset table, not game artwork.
6. Separate **approved**, **working/provisional** and **proposed** source statements; never auto-approve narrative possibilities.
7. Generate a dry-run diff showing create/update/no-op/conflict per character, image and faction. No writes before explicit production authorization.
8. A quest pins a character's approved portrait ID and visual version; a new image model must not silently change existing published appearances.

## Specific continuity checks

- Never resurrect Amon into a present-day live field encounter; use letters, artifacts and archive clues.
- Omar supports the expedition remotely from the Far East; do not depict him as a physical field-team member.
- Preserve Audrey's latest portrait and Maya's user-supplied image rather than recreating their faces.
- Preserve Z's approved face; image variations require face-consistency review.
- Keep Damien/Iris family relationship, Audrey/Damien partnership and Luna/Iris companion relationship consistent.
- Treat former Alexander/Sophia/Iris Cross naming in older documents as historical drafts, not extra current cast.

## Implementation milestones

A. Source registry and character-preview import **without DB writes**.
B. Embedded image extraction, identity mapping and approval UI.
C. Audit Studio read RPC and auth/RLS/media storage, then propose additive persistence and rollback.
D. Import approved canon only with authorization; pin asset versions in Quest Composer.

**Verified at audit:** production and staging `canon.characters` both had zero rows on 2026-10-08. The current schema already includes `visual_profile`, `identity_profile`, `personality_profile`, `knowledge_profile`, `voice_profile` and `ai_rules`.
