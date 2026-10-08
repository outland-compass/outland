import type { CanonReadModel } from './types';

export const studioReadContractFixture: CanonReadModel = {
  universe: {
    id: 'u-development',
    slug: 'development-universe',
    name: 'Development Universe',
    visibility: 'private',
    status: 'draft',
    description: 'Placeholder only. Choose the canonical owning Universe before saving; BEYOND THE ATLAS is a franchise.'
  },
  worlds: [
    {
      id: 'w-development',
      universeId: 'u-development',
      slug: 'development-world',
      name: 'Development World',
      status: 'draft',
      summary: 'Placeholder only.'
    }
  ],
  themes: [],
  worldCities: [
    {
      worldId: 'w-development',
      cityId: 'c-novi-sad',
      relationshipType: 'story'
    }
  ],
  franchises: [
    {
      id: 'f-beyond-atlas',
      universeId: 'u-development',
      slug: 'beyond-the-atlas',
      name: 'BEYOND THE ATLAS',
      description: 'Development fixture only.',
      status: 'draft',
      canonVersion: 1
    }
  ],
  series: [
    {
      id: 's-lost-cartographers',
      franchiseId: 'f-beyond-atlas',
      themeId: null,
      slug: 'the-lost-cartographers',
      name: 'The Lost Cartographers',
      premise: 'Development fixture for the first cross-city narrative.',
      status: 'draft',
      sortOrder: 100
    }
  ],
  characters: [],
  factions: [],
  lore: [
    {
      id: 'l-unbroken-line',
      franchiseId: 'f-beyond-atlas',
      seriesId: null,
      factKey: 'unbroken-line',
      statement: 'The Unbroken Line is an overarching mystery, not a series.',
      canonStatus: 'proposed',
      revealPhase: null,
      visibility: 'internal'
    }
  ],
  rules: [
    {
      id: 'r-no-runtime-invention',
      franchiseId: 'f-beyond-atlas',
      seriesId: null,
      characterId: null,
      ruleType: 'continuity',
      ruleText: 'Runtime AI must not invent global canon.',
      severity: 'error',
      status: 'active'
    }
  ],
  cities: [
    {
      id: 'c-novi-sad',
      countryCode: 'RS',
      slug: 'novi-sad',
      name: 'Novi Sad',
      region: 'Vojvodina',
      timezone: 'Europe/Belgrade',
      defaultLocale: 'sr-RS',
      status: 'draft',
      verificationStatus: 'unverified'
    }
  ]
};
