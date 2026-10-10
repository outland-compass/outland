/**
 * Beyond the Atlas V1.12 — source-derived read-only character import preview.
 * Do not use this as a duplicate canon registry or an automatic database seed.
 * Canonical IDs must be resolved from canon.characters at import time.
 */
export const beyondAtlasCharacterImportPreviewV1 = {
  source: 'SIDEWORLD_Beyond_the_Atlas_Character_Bible_V1_12.docx',
  sourceVersion: '1.12',
  franchiseSlug: 'beyond-the-atlas',
  characters: [
    { slug: 'damien-wayne', name: 'Damien Wayne', role: 'Explorer / Warrior of Light', visual: 'Salt-and-pepper hair, short beard, practical travel clothes', visualStatus: 'current_direction' },
    { slug: 'audrey-quin', name: 'Audrey Quin', role: 'Adventurer / English teacher', visual: 'Long dark ponytail, glasses, elegant practical explorer clothing', visualStatus: 'existing_reference' },
    { slug: 'iris-wayne', name: 'Iris Wayne', role: 'Artist', visual: 'Lighter hair with bangs, blue-green eyes, sketchbook and silver jewelry', visualStatus: 'approved_direction' },
    { slug: 'omar', name: 'Omar', role: 'Remote IT ally', visual: 'Short and slim, short beard, cap, original sci-fi T-shirts', visualStatus: 'current_direction' },
    { slug: 'amon-dimano', name: 'Amon Dimano', role: 'Deceased Teacher', visual: 'Long silver-gray hair and beard, round glasses, deep-red-stone ring', visualStatus: 'canonical_portrait_approved_v1' },
    { slug: 'maria', name: 'Maria', role: 'Messenger', visual: 'Silver-gray hair, rectangular glasses, white blouse, black skirt, blue shawl', visualStatus: 'approved_direction' },
    { slug: 'maya', name: 'Maya', role: 'Apprentice', visual: 'Long dark braids, richly embroidered clothing, ancient book', visualStatus: 'user_supplied_reference' },
    { slug: 'z', name: 'Z', role: 'Director', visual: 'Bald, piercing blue eyes, formal black suit and tie', visualStatus: 'existing_approved_portrait' }
  ],
  editorialDecisions: {
    amonDimano: {
      visualVersion: 1,
      canonicalSourceFile: 'image13.png',
      canonicalSha256: '6c5836fee48b9a3ba9638f8723eda4d2f979d162cd5b929707584c83ef25ed28',
      archivedAlternativeFile: 'image12.png',
      approvalDate: '2026-10-08',
      approvalSource: 'user_selected_original_portrait',
      storageStatus: 'not_uploaded'
    }
  },
  warnings: [
    'Source portraits have been extracted locally; they have not been uploaded to approved media storage.',
    'Omar family name is provisional; do not lock Al-Noor.',
    'Luna is Iris companion; representation requires separate review.',
    'This preview does not create or approve database records.'
  ]
} as const;
