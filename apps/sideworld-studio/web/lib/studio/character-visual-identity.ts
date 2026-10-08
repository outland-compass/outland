/**
 * Character Visual Identity V1 — versioned authoring contract.
 * Existing canon.characters.visual_profile remains the descriptive source.
 * Approved visual asset references are immutable for a published quest version.
 * This module does not create assets, persist data or call an image provider.
 */
export type CharacterVisualIdentityV1 = {
  contractVersion: 1;
  characterId: string;
  franchiseId: string;
  visualVersion: number;
  status: 'draft' | 'approved' | 'retired';
  appearance: {
    description: string;
    immutableTraits: string[];
    palette: string[];
    wardrobeRules: string[];
    forbiddenVariations: string[];
  };
  referenceAssets: {
    assetId: string;
    role: 'canonical_portrait' | 'reference_sheet' | 'expression' | 'pose';
    uri: string;
    approved: boolean;
    contentHash: string;
  }[];
  provenance: {
    source: 'human' | 'ai_assisted';
    generationModel?: string;
    rightsNote: string;
    approvedBy?: string;
    approvedAt?: string;
  };
};

export function validateCharacterVisualIdentityV1(
  identity: CharacterVisualIdentityV1,
  character: { id: string; franchiseId: string; canonStatus: string }
): string[] {
  const issues: string[] = [];
  if (identity.contractVersion !== 1 || !Number.isInteger(identity.visualVersion) || identity.visualVersion < 1) issues.push('Invalid visual identity version');
  if (identity.characterId !== character.id || identity.franchiseId !== character.franchiseId) issues.push('Visual identity character/franchise mismatch');
  if (identity.status === 'approved' && character.canonStatus !== 'approved') issues.push('Character canon must be approved first');
  if (!identity.appearance.description.trim() || !identity.appearance.immutableTraits.length) issues.push('Appearance and immutable traits are required');
  if (!identity.provenance.rightsNote.trim()) issues.push('Asset rights provenance is required');
  if (identity.status === 'approved') {
    if (!identity.provenance.approvedBy || !identity.provenance.approvedAt || !Number.isFinite(Date.parse(identity.provenance.approvedAt))) issues.push('Approval audit fields are required');
    const portraits = identity.referenceAssets.filter(asset => asset.role === 'canonical_portrait' && asset.approved);
    if (portraits.length !== 1) issues.push('Exactly one approved canonical portrait is required');
    if (identity.referenceAssets.some(asset => !asset.assetId.trim() || !asset.contentHash.trim() || !/^https:\/\//.test(asset.uri))) issues.push('Every asset requires ID, hash and HTTPS URL');
  }
  return issues;
}

export type QuestCharacterAppearanceV1 = {
  characterId: string;
  visualVersion: number;
  canonicalPortraitAssetId: string;
  sceneAssetIds: string[];
};

export function pinQuestCharacterAppearanceV1(
  identity: CharacterVisualIdentityV1,
  character: { id: string; franchiseId: string; canonStatus: string },
  sceneAssetIds: string[] = []
): QuestCharacterAppearanceV1 {
  const issues = validateCharacterVisualIdentityV1(identity, character);
  if (issues.length || identity.status !== 'approved') throw new Error('Cannot pin unapproved visual identity: ' + issues.join('; '));
  const portrait = identity.referenceAssets.find(asset => asset.role === 'canonical_portrait' && asset.approved);
  if (!portrait) throw new Error('Canonical portrait missing');
  const approvedAssetIds = new Set(identity.referenceAssets.filter(asset => asset.approved).map(asset => asset.assetId));
  if (sceneAssetIds.some(id => !approvedAssetIds.has(id))) throw new Error('Quest scene references unapproved visual asset');
  return {
    characterId: identity.characterId,
    visualVersion: identity.visualVersion,
    canonicalPortraitAssetId: portrait.assetId,
    sceneAssetIds: [...new Set(sceneAssetIds)]
  };
}
