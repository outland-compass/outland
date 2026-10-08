export type ContainerStatus = 'draft' | 'active' | 'archived';
export type CanonItemStatus = 'draft' | 'proposed' | 'approved' | 'retired';
export type CanonRuleStatus = 'draft' | 'active' | 'retired';

export type UniverseRecord = {
  id: string;
  slug: string;
  name: string;
  visibility: 'private' | 'unlisted' | 'public';
  status: ContainerStatus;
  description: string | null;
};

export type WorldRecord = {
  id: string;
  universeId: string;
  slug: string;
  name: string;
  status: ContainerStatus;
  summary: string | null;
};

export type ThemeRecord = {
  id: string;
  universeId: string | null;
  slug: string;
  name: string;
  description: string | null;
  status: ContainerStatus;
};

export type WorldCityRecord = {
  worldId: string;
  cityId: string;
  relationshipType: 'primary' | 'story' | 'operational' | 'expansion';
};

export type FranchiseRecord = {
  id: string;
  universeId: string;
  slug: string;
  name: string;
  description: string | null;
  status: ContainerStatus;
  canonVersion: number;
};

export type SeriesRecord = {
  id: string;
  franchiseId: string;
  themeId: string | null;
  slug: string;
  name: string;
  premise: string | null;
  status: ContainerStatus;
  sortOrder: number;
};

export type CharacterRecord = {
  id: string;
  franchiseId: string;
  slug: string;
  name: string;
  displayName: string | null;
  role: string | null;
  bio: string | null;
  canonStatus: CanonItemStatus;
};

export type FactionRecord = {
  id: string;
  franchiseId: string;
  slug: string;
  name: string;
  factionType: string | null;
  description: string | null;
  visibility: 'hidden' | 'partial' | 'public';
  canonStatus: CanonItemStatus;
};

export type LoreFactRecord = {
  id: string;
  franchiseId: string;
  seriesId: string | null;
  factKey: string;
  statement: string;
  canonStatus: CanonItemStatus;
  revealPhase: string | null;
  visibility: 'internal' | 'hidden' | 'player_known' | 'public';
};

export type CanonRuleRecord = {
  id: string;
  franchiseId: string;
  seriesId: string | null;
  characterId: string | null;
  ruleType: string;
  ruleText: string;
  severity: 'info' | 'warning' | 'error';
  status: CanonRuleStatus;
};

export type CityRecord = {
  id: string;
  countryCode: string;
  slug: string;
  name: string;
  region: string | null;
  timezone: string;
  defaultLocale: string;
  status: ContainerStatus;
  verificationStatus: 'unverified' | 'partially_verified' | 'verified' | 'disputed';
};

export type CanonReadModel = {
  universe: UniverseRecord;
  worlds: WorldRecord[];
  themes: ThemeRecord[];
  worldCities: WorldCityRecord[];
  franchises: FranchiseRecord[];
  series: SeriesRecord[];
  characters: CharacterRecord[];
  factions: FactionRecord[];
  lore: LoreFactRecord[];
  rules: CanonRuleRecord[];
  cities: CityRecord[];
};

export function isCanonicalStatus(status: ContainerStatus | CanonItemStatus | CanonRuleStatus) {
  return status === 'active' || status === 'approved';
}
