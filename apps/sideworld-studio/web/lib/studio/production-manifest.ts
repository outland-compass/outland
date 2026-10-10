import type { CanonContextPackV0 } from './context-builder';
import type { CityKnowledgePack } from './city-knowledge-types';

export type ProductionInputManifestV1 = {
  manifestVersion: 1;
  universeId: string;
  franchiseId: string;
  cityId: string;
  canonVersion: number;
  canon: CanonContextPackV0;
  cityKnowledge: {
    city: NonNullable<CityKnowledgePack['city']>;
    locations: CityKnowledgePack['locations'];
    facts: CityKnowledgePack['facts'];
    sources: CityKnowledgePack['sources'];
    factSources: CityKnowledgePack['factSources'];
  };
  diagnostics: { code: string; message: string }[];
  readyForGeneration: boolean;
};

export function buildProductionInputManifestV1(
  canon: CanonContextPackV0,
  knowledge: CityKnowledgePack
): ProductionInputManifestV1 {
  if (!knowledge.city) throw new Error('City knowledge has no city identity');
  const city = knowledge.city;
  const diagnostics: ProductionInputManifestV1['diagnostics'] = [];
  const fail = (code: string, message: string) => diagnostics.push({ code, message });
  if (canon.franchise.universeId !== canon.universe.id) fail('FRANCHISE_UNIVERSE', 'Franchise belongs to another universe');
  if (!canon.cities.some(item => item.id === city.id)) fail('CITY_NOT_IN_CONTEXT', 'Selected city is absent from canonical context');
  if (city.verificationStatus !== 'verified') fail('CITY_UNVERIFIED', 'City requires full verification before automated generation');
  const locations = [...knowledge.locations].filter(item => item.cityId === city.id && item.verificationStatus === 'verified' && item.publicAccess === true && Number.isFinite(item.latitude) && Number.isFinite(item.longitude) && Math.abs(item.latitude) <= 90 && Math.abs(item.longitude) <= 180).sort((a, b) => a.id.localeCompare(b.id));
  if (locations.length < 5) fail('INSUFFICIENT_LOCATIONS', 'At least five verified public locations with valid coordinates are required');
  const locationIds = new Set(locations.map(item => item.id));
  const sourceIds = new Set(knowledge.sources.map(item => item.id));
  const supportingLinks = knowledge.factSources.filter(link => link.supportType === 'supports' && sourceIds.has(link.sourceId));
  const supportedFactIds = new Set(supportingLinks.map(link => link.factId));
  const facts = [...knowledge.facts].filter(item => item.cityId === city.id && item.verificationStatus === 'verified' && supportedFactIds.has(item.id) && (item.locationId === null || locationIds.has(item.locationId))).sort((a, b) => a.id.localeCompare(b.id));
  if (!facts.length) fail('NO_SUPPORTED_FACTS', 'No verified source-backed facts are available');
  const factIds = new Set(facts.map(item => item.id));
  const factSources = supportingLinks.filter(link => factIds.has(link.factId) && sourceIds.has(link.sourceId)).sort((a, b) => (a.factId + ':' + a.sourceId).localeCompare(b.factId + ':' + b.sourceId));
  if (!factSources.length) fail('NO_VALID_SOURCES', 'No valid supporting source relationships exist');
  const includedSourceIds = new Set(factSources.map(item => item.sourceId));
  const sources = [...knowledge.sources].filter(item => includedSourceIds.has(item.id)).sort((a, b) => a.id.localeCompare(b.id));
  return {
    manifestVersion: 1,
    universeId: canon.universe.id,
    franchiseId: canon.franchise.id,
    cityId: city.id,
    canonVersion: canon.franchise.canonVersion,
    canon,
    cityKnowledge: { city, locations, facts, sources, factSources },
    diagnostics,
    readyForGeneration: diagnostics.length === 0
  };
}
