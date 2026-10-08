# Character Visual Identity — Audit and Implementation V1

**Audit date:** 2026-10-08. **Status:** Read-only production/staging inspection completed; code-level contract implemented; no database migrations or visual assets created.

## Verified production and staging state

Both projects contain `canon.characters` with `identity_profile`, `personality_profile`, `knowledge_profile`, `voice_profile`, `visual_profile`, `ai_rules` and `metadata` JSONB columns. Both have `canon.franchises`. Both currently return **zero** character records. The existing `shared.assets` table is for owned/physical assets (including candidate/world association and acquisition price), **not** a suitable character-art registry. Do not reuse it for game artwork without a separate design review.

## Decision

- Reuse the canonical `canon.characters` entity and its `visual_profile` for stable descriptive appearance. Never duplicate character or universe registries.
- Define a versioned `CharacterVisualIdentityV1` contract for canonical portrait, reference sheet, expression/pose variants, immutable traits, style constraints, approval and provenance.
- Every published quest appearance pins `characterId`, `visualVersion` and approved asset IDs. A later redesign creates a new visual version; existing published quest versions retain the old references until explicitly republished.
- Character portraits are generated once per approved version, then reused directly whenever possible. Scene variants may be generated from approved reference assets, but require review; prompts alone cannot guarantee identity consistency.
- Asset IDs, URLs and hashes are references only; actual media storage, permissions, rights and schema are not yet implemented.

## Next implementation gates

1. Inspect GitHub migrations, RLS, storage policies, Studio read RPC payload and app dependencies before proposing persistence changes.
2. Determine whether approved visual versions should be stored in existing `visual_profile` or an additive versioned media table. Favor immutable, auditable asset version records, but avoid premature migrations.
3. Build owner-only Character Bible and visual asset review screens; keep generation disabled by default.
4. Connect an image provider only after asset rights, model choice, cost controls and review workflow are agreed.
5. Test one character across at least two quests and two cities, checking portrait reuse and pinned version consistency.
6. No production database changes without explicit approval; staging for higher-risk RLS/storage changes.

## Implementation

`apps/sideworld-studio/web/lib/studio/character-visual-identity.ts` defines the read-only contract, validation and quest appearance pinning. This does **not** assert that live RPC currently exposes `visual_profile` or that visual assets exist.
