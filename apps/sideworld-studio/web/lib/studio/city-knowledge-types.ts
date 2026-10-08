export type CityKnowledgeLocation = {
  id: string;
  cityId: string;
  slug: string;
  name: string;
  locationType: string;
  latitude: number;
  longitude: number;
  addressText: string | null;
  publicAccess: boolean | null;
  accessibilityProfile: Record<string, unknown>;
  safetyProfile: Record<string, unknown>;
  openingHours: Record<string, unknown>;
  verificationStatus: 'unverified' | 'partially_verified' | 'verified' | 'disputed';
  fieldVerifiedAt: string | null;
  metadata: Record<string, unknown>;
};

export type CityKnowledgeFact = {
  id: string;
  cityId: string;
  locationId: string | null;
  factKey: string;
  statement: string;
  factType: string;
  verificationStatus: 'unverified' | 'partially_verified' | 'verified' | 'disputed';
  confidence: number | null;
  validFrom: string | null;
  validTo: string | null;
  lastVerifiedAt: string | null;
  metadata: Record<string, unknown>;
};

export type CityKnowledgeSource = {
  id: string;
  url: string | null;
  publisher: string | null;
  title: string;
  sourceType: string;
  publishedAt: string | null;
  retrievedAt: string;
  trustTier: string | null;
  metadata: Record<string, unknown>;
};

export type CityKnowledgeFactSource = {
  factId: string;
  sourceId: string;
  supportType: 'supports' | 'contradicts' | 'context';
  note: string | null;
};

export type CityKnowledgePack = {
  city: {
    id: string;
    countryCode: string;
    slug: string;
    name: string;
    region: string | null;
    timezone: string;
    defaultLocale: string;
    status: 'draft' | 'active' | 'archived';
    verificationStatus: 'unverified' | 'partially_verified' | 'verified' | 'disputed';
  } | null;
  locations: CityKnowledgeLocation[];
  facts: CityKnowledgeFact[];
  sources: CityKnowledgeSource[];
  factSources: CityKnowledgeFactSource[];
};
