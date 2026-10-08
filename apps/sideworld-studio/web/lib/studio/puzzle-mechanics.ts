/**
 * SIDEWORLD Puzzle Mechanics Registry V1.
 *
 * Pure, versioned authoring contracts. No database or AI calls.
 * Puzzle candidates are never publishable without independent review.
 */
export const puzzleMechanicsV1 = [
  {
    id: 'observation',
    version: 1,
    label: 'Observation',
    inputRequirements: ['verified_public_location', 'supported_observable_fact'],
    playerInteraction: 'text_answer',
    answerValidationMode: 'normalized_text',
    hintStrategy: 'progressive',
    accessibilityFallback: 'alternate_text_clue',
    safetyConstraints: ['public_access_only', 'no_unsafe_positioning'],
    estimatedMinutes: 4,
    automatedChecks: ['supported_fact', 'unambiguous_answer', 'unique_location']
  },
  {
    id: 'deduction',
    version: 1,
    label: 'Deduction',
    inputRequirements: ['verified_public_location', 'two_supported_facts'],
    playerInteraction: 'text_answer',
    answerValidationMode: 'normalized_text',
    hintStrategy: 'progressive',
    accessibilityFallback: 'alternate_text_clue',
    safetyConstraints: ['public_access_only', 'no_unsafe_positioning'],
    estimatedMinutes: 6,
    automatedChecks: ['supported_fact', 'unambiguous_answer', 'reasoning_validity']
  },
  {
    id: 'sequence',
    version: 1,
    label: 'Sequence',
    inputRequirements: ['verified_public_location', 'ordered_supported_facts'],
    playerInteraction: 'ordered_choices',
    answerValidationMode: 'exact_order',
    hintStrategy: 'progressive',
    accessibilityFallback: 'accessible_list',
    safetyConstraints: ['public_access_only', 'no_unsafe_positioning'],
    estimatedMinutes: 5,
    automatedChecks: ['supported_fact', 'unique_order', 'accessible_controls']
  },
  {
    id: 'cipher',
    version: 1,
    label: 'Cipher',
    inputRequirements: ['verified_public_location', 'explicit_cipher_key', 'supported_clue'],
    playerInteraction: 'text_answer',
    answerValidationMode: 'normalized_text',
    hintStrategy: 'progressive',
    accessibilityFallback: 'text_equivalent_cipher',
    safetyConstraints: ['public_access_only', 'no_unsafe_positioning'],
    estimatedMinutes: 7,
    automatedChecks: ['cipher_roundtrip', 'unambiguous_answer', 'key_available']
  },
  {
    id: 'navigation',
    version: 1,
    label: 'Navigation',
    inputRequirements: ['two_verified_public_locations', 'safe_route'],
    playerInteraction: 'location_arrival',
    answerValidationMode: 'location_or_accessible_fallback',
    hintStrategy: 'progressive',
    accessibilityFallback: 'manual_arrival_confirmation',
    safetyConstraints: ['public_access_only', 'pedestrian_route_review'],
    estimatedMinutes: 8,
    automatedChecks: ['valid_coordinates', 'route_review_required', 'accessible_fallback']
  },
  {
    id: 'dialogue',
    version: 1,
    label: 'Dialogue',
    inputRequirements: ['approved_character', 'approved_canon_context', 'supported_clue'],
    playerInteraction: 'choice',
    answerValidationMode: 'choice_id',
    hintStrategy: 'progressive',
    accessibilityFallback: 'text_dialogue',
    safetyConstraints: ['canon_consistency', 'no_unverified_real_world_claims'],
    estimatedMinutes: 5,
    automatedChecks: ['canon_consistency', 'unique_correct_choice', 'supported_fact']
  }
] as const;

export type PuzzleMechanicIdV1 = (typeof puzzleMechanicsV1)[number]['id'];

export function getPuzzleMechanicV1(id: string) {
  return puzzleMechanicsV1.find(mechanic => mechanic.id === id) ?? null;
}

export type PuzzleCandidateV1 = {
  mechanicId: PuzzleMechanicIdV1;
  mechanicVersion: 1;
  locationId: string;
  factIds: string[];
  characterIds: string[];
  prompt: string;
  acceptedAnswers: string[];
  hints: string[];
  estimatedMinutes: number;
};

export function validatePuzzleCandidateV1(
  candidate: PuzzleCandidateV1,
  allowed: { locationIds: string[]; factIds: string[]; characterIds: string[] }
): string[] {
  const issues: string[] = [];
  const mechanic = getPuzzleMechanicV1(candidate.mechanicId);
  if (!mechanic || candidate.mechanicVersion !== 1) issues.push('Unsupported mechanic version');
  if (!allowed.locationIds.includes(candidate.locationId)) issues.push('Location is not approved in production manifest');
  if (!candidate.factIds.length || candidate.factIds.some(id => !allowed.factIds.includes(id))) issues.push('Puzzle facts must be supported by the production manifest');
  if (candidate.characterIds.some(id => !allowed.characterIds.includes(id))) issues.push('Character is not in approved canon');
  if (!candidate.prompt.trim()) issues.push('Puzzle prompt is required');
  if (!candidate.acceptedAnswers.length || candidate.acceptedAnswers.some(value => !value.trim())) issues.push('Non-empty accepted answers are required');
  if (candidate.hints.length < 2 || candidate.hints.some(value => !value.trim())) issues.push('At least two progressive hints are required');
  if (!Number.isFinite(candidate.estimatedMinutes) || candidate.estimatedMinutes < 1 || candidate.estimatedMinutes > 30) issues.push('Estimated minutes must be between 1 and 30');
  return issues;
}
