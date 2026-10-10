import { NextRequest, NextResponse } from 'next/server';

import { authorize } from '@/lib/studio/auth';
import { callStudioRpc } from '@/lib/studio/rpc';

export const runtime = 'nodejs';

type Entity = 'universe' | 'franchise' | 'series' | 'lore' | 'rule' | 'world' | 'theme' | 'character' | 'faction' | 'country' | 'city' | 'worldCity' | 'location' | 'locationFact' | 'source' | 'factSource';

function text(value: unknown, max = 4000) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, max);
}

function nullableUuid(value: unknown) {
  const v = text(value, 64);
  return v ? requiredUuid(v, 'optional UUID') : null;
}

function requiredUuid(value: unknown, field: string) {
  const v = text(value, 64);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v)) {
    throw new Error(`${field} must be a UUID`);
  }
  return v;
}

function optionalId(value: unknown) {
  const v = text(value, 64);
  return v ? requiredUuid(v, 'id') : null;
}

function integer(value: unknown, field: string, fallback: number) {
  const n = Number(value ?? fallback);
  if (!Number.isInteger(n) || n <= 0) throw new Error(`${field} must be a positive integer`);
  return n;
}

function decimalOrNull(value: unknown, field: string, min: number, max: number) {
  if (value === '' || value == null) return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n < min || n > max) {
    throw new Error(`${field} must be between ${min} and ${max}`);
  }
  return n;
}

function requiredDecimal(value: unknown, field: string, min: number, max: number) {
  const n = decimalOrNull(value, field, min, max);
  if (n == null) throw new Error(`${field} is required`);
  return n;
}

function booleanOrNull(value: unknown) {
  if (value === '' || value == null) return null;
  if (value === true || value === 'true' || value === 'on') return true;
  if (value === false || value === 'false' || value === 'off') return false;
  throw new Error('boolean value is invalid');
}

function timestampOrNull(value: unknown, field: string) {
  const v = text(value, 64);
  if (!v) return null;
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) throw new Error(`${field} must be a valid timestamp`);
  return d.toISOString();
}

function oneOf(value: unknown, field: string, allowed: readonly string[], fallback: string) {
  const v = text(value, 64) || fallback;
  if (!allowed.includes(v)) throw new Error(`${field} is invalid`);
  return v;
}

function requiredText(value: unknown, field: string, max = 4000) {
  const v = text(value, max);
  if (!v) throw new Error(`${field} is required`);
  return v;
}

function slug(value: unknown) {
  const v = requiredText(value, 'slug', 120).toLowerCase();
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(v)) {
    throw new Error('slug must be lowercase kebab-case');
  }
  return v;
}

function buildRpc(entity: Entity, input: Record<string, unknown>) {
  switch (entity) {
    case 'universe':
      return {
        name: 'sideworld_studio_save_universe',
        body: {
          p_id: optionalId(input.id),
          p_slug: slug(input.slug),
          p_name: requiredText(input.name, 'name', 160),
          p_visibility: oneOf(input.visibility, 'visibility', ['private','unlisted','public'], 'private'),
          p_status: oneOf(input.status, 'status', ['draft','active','archived'], 'draft'),
          p_description: text(input.description)
        }
      };
    case 'franchise':
      return {
        name: 'sideworld_studio_save_franchise',
        body: {
          p_id: optionalId(input.id),
          p_universe_id: requiredUuid(input.universeId, 'universeId'),
          p_slug: slug(input.slug),
          p_name: requiredText(input.name, 'name', 160),
          p_description: text(input.description),
          p_status: oneOf(input.status, 'status', ['draft','active','archived'], 'draft'),
          p_canon_version: integer(input.canonVersion, 'canonVersion', 1)
        }
      };
    case 'series':
      return {
        name: 'sideworld_studio_save_series',
        body: {
          p_id: optionalId(input.id),
          p_franchise_id: requiredUuid(input.franchiseId, 'franchiseId'),
          p_theme_id: nullableUuid(input.themeId),
          p_slug: slug(input.slug),
          p_name: requiredText(input.name, 'name', 160),
          p_premise: text(input.premise),
          p_status: oneOf(input.status, 'status', ['draft','active','archived'], 'draft'),
          p_sort_order: integer(input.sortOrder, 'sortOrder', 100)
        }
      };
    case 'lore':
      return {
        name: 'sideworld_studio_save_lore_fact',
        body: {
          p_id: optionalId(input.id),
          p_franchise_id: requiredUuid(input.franchiseId, 'franchiseId'),
          p_series_id: nullableUuid(input.seriesId),
          p_fact_key: requiredText(input.factKey, 'factKey', 160),
          p_statement: requiredText(input.statement, 'statement'),
          p_canon_status: oneOf(input.canonStatus, 'canonStatus', ['draft','proposed','approved','retired'], 'draft'),
          p_reveal_phase: text(input.revealPhase, 160),
          p_visibility: oneOf(input.visibility, 'visibility', ['internal','hidden','player_known','public'], 'internal')
        }
      };
    case 'world':
      return {
        name: 'sideworld_studio_save_world',
        body: {
          p_id: optionalId(input.id),
          p_universe_id: requiredUuid(input.universeId, 'universeId'),
          p_slug: slug(input.slug),
          p_name: requiredText(input.name, 'name', 160),
          p_status: oneOf(input.status, 'status', ['draft','active','archived'], 'draft'),
          p_summary: text(input.summary)
        }
      };
    case 'theme':
      return {
        name: 'sideworld_studio_save_theme',
        body: {
          p_id: optionalId(input.id),
          p_universe_id: nullableUuid(input.universeId),
          p_slug: slug(input.slug),
          p_name: requiredText(input.name, 'name', 160),
          p_description: text(input.description),
          p_status: oneOf(input.status, 'status', ['draft','active','archived'], 'draft')
        }
      };
    case 'character':
      return {
        name: 'sideworld_studio_save_character',
        body: {
          p_id: optionalId(input.id),
          p_franchise_id: requiredUuid(input.franchiseId, 'franchiseId'),
          p_slug: slug(input.slug),
          p_name: requiredText(input.name, 'name', 160),
          p_display_name: text(input.displayName, 160),
          p_role: text(input.role, 160),
          p_age: input.age === '' || input.age == null ? null : integer(input.age, 'age', 1),
          p_bio: text(input.bio),
          p_canon_status: oneOf(input.canonStatus, 'canonStatus', ['draft','proposed','approved','retired'], 'draft')
        }
      };
    case 'faction':
      return {
        name: 'sideworld_studio_save_faction',
        body: {
          p_id: optionalId(input.id),
          p_franchise_id: requiredUuid(input.franchiseId, 'franchiseId'),
          p_slug: slug(input.slug),
          p_name: requiredText(input.name, 'name', 160),
          p_faction_type: text(input.factionType, 160),
          p_description: text(input.description),
          p_visibility: oneOf(input.visibility, 'visibility', ['hidden','partial','public'], 'hidden'),
          p_canon_status: oneOf(input.canonStatus, 'canonStatus', ['draft','proposed','approved','retired'], 'draft')
        }
      };
    case 'country':
      return {
        name: 'sideworld_studio_save_country',
        body: {
          p_code: requiredText(input.code, 'code', 2).toUpperCase(),
          p_name: requiredText(input.name, 'name', 160),
          p_default_locale: text(input.defaultLocale, 32)
        }
      };
    case 'city':
      return {
        name: 'sideworld_studio_save_city',
        body: {
          p_id: optionalId(input.id),
          p_country_code: requiredText(input.countryCode, 'countryCode', 2).toUpperCase(),
          p_slug: slug(input.slug),
          p_name: requiredText(input.name, 'name', 160),
          p_region: text(input.region, 160),
          p_timezone: requiredText(input.timezone, 'timezone', 80),
          p_default_locale: requiredText(input.defaultLocale, 'defaultLocale', 32),
          p_latitude: decimalOrNull(input.latitude, 'latitude', -90, 90),
          p_longitude: decimalOrNull(input.longitude, 'longitude', -180, 180),
          p_status: oneOf(input.status, 'status', ['draft','active','archived'], 'draft'),
          p_verification_status: oneOf(input.verificationStatus, 'verificationStatus', ['unverified','partially_verified','verified','disputed'], 'unverified')
        }
      };
    case 'worldCity':
      return {
        name: 'sideworld_studio_save_world_city',
        body: {
          p_world_id: requiredUuid(input.worldId, 'worldId'),
          p_city_id: requiredUuid(input.cityId, 'cityId'),
          p_relationship_type: oneOf(input.relationshipType, 'relationshipType', ['primary','story','operational','expansion'], 'story')
        }
      };
    case 'location':
      return {
        name: 'sideworld_studio_save_location',
        body: {
          p_id: optionalId(input.id),
          p_city_id: requiredUuid(input.cityId, 'cityId'),
          p_slug: slug(input.slug),
          p_name: requiredText(input.name, 'name', 160),
          p_location_type: requiredText(input.locationType, 'locationType', 80),
          p_latitude: requiredDecimal(input.latitude, 'latitude', -90, 90),
          p_longitude: requiredDecimal(input.longitude, 'longitude', -180, 180),
          p_address_text: text(input.addressText, 500),
          p_public_access: booleanOrNull(input.publicAccess),
          p_verification_status: oneOf(input.verificationStatus, 'verificationStatus', ['unverified','partially_verified','verified','disputed'], 'unverified')
        }
      };
    case 'locationFact':
      return {
        name: 'sideworld_studio_save_location_fact',
        body: {
          p_id: optionalId(input.id),
          p_city_id: requiredUuid(input.cityId, 'cityId'),
          p_location_id: nullableUuid(input.locationId),
          p_fact_key: requiredText(input.factKey, 'factKey', 160),
          p_statement: requiredText(input.statement, 'statement'),
          p_fact_type: requiredText(input.factType, 'factType', 80),
          p_verification_status: oneOf(input.verificationStatus, 'verificationStatus', ['unverified','partially_verified','verified','disputed'], 'unverified'),
          p_confidence: decimalOrNull(input.confidence, 'confidence', 0, 1)
        }
      };
    case 'source':
      return {
        name: 'sideworld_studio_save_source',
        body: {
          p_id: optionalId(input.id),
          p_url: text(input.url, 2000),
          p_publisher: text(input.publisher, 300),
          p_title: requiredText(input.title, 'title', 500),
          p_source_type: requiredText(input.sourceType, 'sourceType', 80),
          p_published_at: timestampOrNull(input.publishedAt, 'publishedAt'),
          p_trust_tier: text(input.trustTier, 80)
        }
      };
    case 'factSource':
      return {
        name: 'sideworld_studio_save_fact_source',
        body: {
          p_fact_id: requiredUuid(input.factId, 'factId'),
          p_source_id: requiredUuid(input.sourceId, 'sourceId'),
          p_support_type: oneOf(input.supportType, 'supportType', ['supports','contradicts','context'], 'supports'),
          p_note: text(input.note, 1000)
        }
      };
    case 'rule':
      return {
        name: 'sideworld_studio_save_canon_rule',
        body: {
          p_id: optionalId(input.id),
          p_franchise_id: requiredUuid(input.franchiseId, 'franchiseId'),
          p_series_id: nullableUuid(input.seriesId),
          p_character_id: nullableUuid(input.characterId),
          p_rule_type: requiredText(input.ruleType, 'ruleType', 160),
          p_rule_text: requiredText(input.ruleText, 'ruleText'),
          p_severity: oneOf(input.severity, 'severity', ['info','warning','error'], 'error'),
          p_status: oneOf(input.status, 'status', ['draft','active','retired'], 'draft')
        }
      };
  }
}

export async function POST(request: NextRequest) {
  if (request.headers.get('origin') !== request.nextUrl.origin) {
    return NextResponse.json({ error: 'Invalid origin' }, { status: 403 });
  }
  if (!await authorize(request, NextResponse.next())) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const contentLength = Number(request.headers.get('content-length') ?? '0');
  if (contentLength > 24_000) {
    return NextResponse.json({ error: 'Payload too large' }, { status: 413 });
  }

  let body: { entity?: unknown; input?: unknown };

  try {
    const raw = await request.text();
    if (new TextEncoder().encode(raw).byteLength > 24_000) {
      return NextResponse.json({ error: 'Payload too large' }, { status: 413 });
    }
    body = JSON.parse(raw);
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return NextResponse.json({ error: 'JSON object required' }, { status: 400 });
    }
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const entity = text(body.entity, 32) as Entity;
  if (!['universe','franchise','series','lore','rule','world','theme','character','faction','country','city','worldCity','location','locationFact','source','factSource'].includes(entity)) {
    return NextResponse.json({ error: 'Unsupported entity' }, { status: 400 });
  }

  if (!body.input || typeof body.input !== 'object' || Array.isArray(body.input)) {
    return NextResponse.json({ error: 'input is required' }, { status: 400 });
  }

  // The guarded RPC validates ownership and performs the mutation atomically.
  // Keep disabled until migrations, staging integration tests, and env setup pass.
  if (process.env.SIDEWORLD_STUDIO_GUARDED_WRITES !== 'enabled') {
    return NextResponse.json({ error: 'Studio writes temporarily disabled pending universe ownership validation' }, { status: 503 });
  }

  const selectedUniverse = text(request.nextUrl.searchParams.get('universe'), 120);
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(selectedUniverse)) {
    return NextResponse.json({ error: 'A valid selected universe is required' }, { status: 400 });
  }

  const rootEntities = ['world', 'theme', 'franchise'];
  const canonEntities = ['series', 'character', 'faction', 'lore', 'rule'];
  if (!rootEntities.includes(entity) && !canonEntities.includes(entity)) {
    // Geo records are shared, and universe creation is a separate admin workflow.
    return NextResponse.json({ error: 'Entity is not supported by guarded writes' }, { status: 403 });
  }

  try {
    const rpc = buildRpc(entity, body.input as Record<string, unknown>);
    const guardedName = rootEntities.includes(entity)
      ? 'sideworld_studio_guarded_save_root'
      : 'sideworld_studio_guarded_save_canon';
    const id = await callStudioRpc<string>(guardedName, {
      p_universe_slug: selectedUniverse,
      p_entity: entity,
      p_input: rpc.body
    });
    return NextResponse.json({ id });
  } catch (error) {
    console.error('Guarded Studio write failed', error);
    return NextResponse.json({ error: 'Authoring failed. Check server logs.' }, { status: 400 });
  }
}
