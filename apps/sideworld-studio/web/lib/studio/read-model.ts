import 'server-only';

import { studioReadContractFixture } from './fixture';
import type { CanonReadModel } from './types';

export async function getStudioReadModel(): Promise<CanonReadModel> {
  // V0-B read contract only.
  // This intentionally does not connect to production/private schemas yet.
  return structuredClone(studioReadContractFixture);
}
