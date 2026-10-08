import 'server-only';

import { callStudioRpc } from './rpc';
import type { CityKnowledgePack } from './city-knowledge-types';

export async function getCityKnowledge(cityId: string): Promise<CityKnowledgePack> {
  return callStudioRpc<CityKnowledgePack>('sideworld_studio_city_knowledge', {
    p_city_id: cityId
  });
}
