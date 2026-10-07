import { NextRequest, NextResponse } from 'next/server';

import { STUDIO_SESSION_COOKIE, verifyStudioSession } from '@/lib/session';
import { callStudioRpc } from '@/lib/studio/rpc';

export const runtime = 'nodejs';

type Entity = 'universe' | 'franchise' | 'series' | 'lore' | 'rule' | 'world' | 'theme' | 'character' | 'faction' | 'country' | 'city' | 'worldCity';

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
          p_latitude: input.latitude === '' || input.latitude == null ? null : Number(input.latitude),
          p_longitude: input.longitude === '' || input.longitude == null ? null : Number(input.longitude),
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
  try {
    if (!verifyStudioSession(request.cookies.get(STUDIO_SESSION_COOKIE)?.value)) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
  } catch {
    return NextResponse.json({ error: 'Studio session unavailable' }, { status: 503 });
  }

  const contentLength = Number(request.headers.get('content-length') ?? '0');
  if (contentLength > 24_000) {
    return NextResponse.json({ error: 'Payload too large' }, { status: 413 });
  }

  let body: { entity?: unknown; input?: unknown };

  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const entity = text(body.entity, 32) as Entity;
  if (!['universe','franchise','series','lore','rule','world','theme','character','faction','country','city','worldCity'].includes(entity)) {
    return NextResponse.json({ error: 'Unsupported entity' }, { status: 400 });
  }

  if (!body.input || typeof body.input !== 'object' || Array.isArray(body.input)) {
    return NextResponse.json({ error: 'input is required' }, { status: 400 });
  }

  try {
    const rpc = buildRpc(entity, body.input as Record<string, unknown>);
    const id = await callStudioRpc<string>(rpc.name, rpc.body);
    return NextResponse.json({ id });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Authoring failed';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
