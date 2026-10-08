import 'server-only';

import type {
  CanonReadModel,
  CanonRuleRecord,
  CharacterRecord,
  CityRecord,
  FactionRecord,
  FranchiseRecord,
  LoreFactRecord,
  SeriesRecord,
  ThemeRecord,
  UniverseRecord,
  WorldCityRecord,
  WorldRecord
} from './types';

export type CanonContextSelection = {
  franchiseSlug: string;
  seriesSlugs?: string[];
  worldSlugs?: string[];
  citySlugs?: string[];
  proposedLoreKeys?: string[];
};

export type CanonContextPackV0 = {
  contextVersion: 1;
  selection: {
    universeSlug: string;
    franchiseSlug: string;
    seriesSlugs: string[];
    worldSlugs: string[];
    citySlugs: string[];
    proposedLoreKeys: string[];
  };
  universe: UniverseRecord;
  franchise: FranchiseRecord;
  worlds: WorldRecord[];
  themes: ThemeRecord[];
  worldCities: WorldCityRecord[];
  series: SeriesRecord[];
  characters: CharacterRecord[];
  factions: FactionRecord[];
  lore: LoreFactRecord[];
  rules: CanonRuleRecord[];
  cities: CityRecord[];
};

function sorted<T>(items: T[], key: (item: T) => string) {
  return [...items].sort((a, b) => key(a).localeCompare(key(b)));
}

function selectedSet(values?: string[]) {
  return new Set((values ?? []).map((value) => value.trim()).filter(Boolean));
}

export function buildCanonContextV0(
  model: CanonReadModel,
  selection: CanonContextSelection
): CanonContextPackV0 {
  const franchise = model.franchises.find(
    (item) => item.slug === selection.franchiseSlug && item.status === 'active'
  );

  if (!franchise) {
    throw new Error(`Active franchise not found: ${selection.franchiseSlug}`);
  }

  const seriesSlugs = selectedSet(selection.seriesSlugs);
  const worldSlugs = selectedSet(selection.worldSlugs);
  const citySlugs = selectedSet(selection.citySlugs);
  const proposedLoreKeys = selectedSet(selection.proposedLoreKeys);

  const worlds = sorted(
    model.worlds.filter(
      (item) => worldSlugs.has(item.slug) && item.status !== 'archived'
    ),
    (item) => item.slug
  );

  const worldIds = new Set(worlds.map((item) => item.id));

  const worldCities = [...model.worldCities]
    .filter((item) => worldIds.has(item.worldId))
    .sort((a, b) =>
      `${a.worldId}:${a.cityId}:${a.relationshipType}`.localeCompare(
        `${b.worldId}:${b.cityId}:${b.relationshipType}`
      )
    );

  const linkedCityIds = new Set(worldCities.map((item) => item.cityId));

  const cities = sorted(
    model.cities.filter(
      (item) => linkedCityIds.has(item.id) || citySlugs.has(item.slug)
    ),
    (item) => item.slug
  );

  const series = [...model.series]
    .filter(
      (item) =>
        item.franchiseId === franchise.id &&
        (item.status === 'active' || seriesSlugs.has(item.slug))
    )
    .sort((a, b) => a.sortOrder - b.sortOrder || a.slug.localeCompare(b.slug));

  const includedSeriesIds = new Set(series.map((item) => item.id));
  const includedThemeIds = new Set(
    series.map((item) => item.themeId).filter((value): value is string => value !== null)
  );

  const themes = sorted(
    model.themes.filter(
      (item) => includedThemeIds.has(item.id) && item.status !== 'archived'
    ),
    (item) => item.slug
  );

  const characters = sorted(
    model.characters.filter(
      (item) =>
        item.franchiseId === franchise.id && item.canonStatus === 'approved'
    ),
    (item) => item.slug
  );

  const factions = sorted(
    model.factions.filter(
      (item) =>
        item.franchiseId === franchise.id && item.canonStatus === 'approved'
    ),
    (item) => item.slug
  );

  const lore = sorted(
    model.lore.filter(
      (item) =>
        item.franchiseId === franchise.id &&
        (item.canonStatus === 'approved' ||
          (item.canonStatus === 'proposed' && proposedLoreKeys.has(item.factKey))) &&
        (item.seriesId === null || includedSeriesIds.has(item.seriesId))
    ),
    (item) => item.factKey
  );

  const rules = [...model.rules]
    .filter(
      (item) =>
        item.franchiseId === franchise.id &&
        item.status === 'active' &&
        (item.seriesId === null || includedSeriesIds.has(item.seriesId))
    )
    .sort((a, b) => {
      const severity = { error: 0, warning: 1, info: 2 } as const;
      return severity[a.severity] - severity[b.severity] || a.ruleType.localeCompare(b.ruleType);
    });

  return {
    contextVersion: 1,
    selection: {
      universeSlug: model.universe.slug,
      franchiseSlug: franchise.slug,
      seriesSlugs: [...seriesSlugs].sort(),
      worldSlugs: [...worldSlugs].sort(),
      citySlugs: [...citySlugs].sort(),
      proposedLoreKeys: [...proposedLoreKeys].sort()
    },
    universe: model.universe,
    franchise,
    worlds,
    themes,
    worldCities,
    series,
    characters,
    factions,
    lore,
    rules,
    cities
  };
}
