import type { ProductionInputManifestV1 } from './production-manifest';
import {
  buildPuzzleGenerationRequestV1,
  reviewPuzzleGenerationOutputV1,
  type PuzzleGenerationRequestV1,
  type PuzzleGenerationReviewV1
} from './puzzle-generation';
import type { PuzzleMechanicIdV1 } from './puzzle-mechanics';

/**
 * Provider-independent orchestration boundary.
 * A caller must explicitly supply a server-side provider and a budget.
 * No provider credentials, network calls, database writes or publishing live here.
 */
export type PuzzleProviderV1 = {
  generateJson: (request: PuzzleGenerationRequestV1, limits: {
    maxOutputTokens: number;
    timeoutMs: number;
  }) => Promise<{ output: unknown; inputTokens: number; outputTokens: number }>;
};

export type PuzzleGenerationBudgetV1 = {
  maxCandidates: number;
  maxOutputTokens: number;
  timeoutMs: number;
  maxTotalTokens: number;
};

export const DEFAULT_PUZZLE_BUDGET_V1: PuzzleGenerationBudgetV1 = {
  maxCandidates: 5,
  maxOutputTokens: 2400,
  timeoutMs: 20_000,
  maxTotalTokens: 12_000
};

function checkBudget(budget: PuzzleGenerationBudgetV1) {
  if (!Number.isInteger(budget.maxCandidates) || budget.maxCandidates < 1 || budget.maxCandidates > 10) throw new Error('Invalid candidate budget');
  if (!Number.isInteger(budget.maxOutputTokens) || budget.maxOutputTokens < 256 || budget.maxOutputTokens > 4096) throw new Error('Invalid output token budget');
  if (!Number.isInteger(budget.maxTotalTokens) || budget.maxTotalTokens < budget.maxOutputTokens || budget.maxTotalTokens > 20_000) throw new Error('Invalid total token budget');
  if (!Number.isInteger(budget.timeoutMs) || budget.timeoutMs < 1000 || budget.timeoutMs > 30_000) throw new Error('Invalid timeout budget');
}

export async function generatePuzzleDraftsV1(
  manifest: ProductionInputManifestV1,
  options: {
    mechanicIds: PuzzleMechanicIdV1[];
    locale?: string;
    budget?: PuzzleGenerationBudgetV1;
  },
  provider: PuzzleProviderV1
): Promise<{ review: PuzzleGenerationReviewV1; usage: { inputTokens: number; outputTokens: number } }> {
  const budget = options.budget ?? DEFAULT_PUZZLE_BUDGET_V1;
  checkBudget(budget);
  const request = buildPuzzleGenerationRequestV1(manifest, {
    mechanicIds: options.mechanicIds,
    maximumCandidates: budget.maxCandidates,
    locale: options.locale
  });
  // Provider must implement a real abort/timeout; this boundary passes an upper limit.
  const response = await provider.generateJson(request, {
    maxOutputTokens: budget.maxOutputTokens,
    timeoutMs: budget.timeoutMs
  });
  if (!Number.isInteger(response.inputTokens) || response.inputTokens < 0 ||
      !Number.isInteger(response.outputTokens) || response.outputTokens < 0 ||
      response.outputTokens > budget.maxOutputTokens ||
      response.inputTokens + response.outputTokens > budget.maxTotalTokens) {
    throw new Error('AI provider exceeded or did not report valid token usage');
  }
  return {
    review: reviewPuzzleGenerationOutputV1(response.output, manifest, request),
    usage: { inputTokens: response.inputTokens, outputTokens: response.outputTokens }
  };
}
