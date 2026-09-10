// COMPASS listing importer. Fetches allowlisted property portals server-side and
// returns normalized Signal fields. Never infers or invents missing values.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { extractJsonLdImageUrl, extractMetaImageUrl } from './image.ts';

const ALLOWED_DOMAINS = ['oglasi.rs', 'realitica.com', 'estitor.com', 'nekretnine.rs'];
const FETCH_TIMEOUT_MS = 12_000;
const MAX_RESPONSE_BYTES = 2_000_000;
const TRACKING_PARAMS = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content', 'fbclid', 'gclid'];

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

interface ImportedListing {
  source_name: string | null;
  source_url: string;
  source_listing_id: string | null;
  title: string | null;
  location: string | null;
  price: number | null;
  currency: string | null;
  area_m2: number | null;
  description: string | null;
  image_url: string | null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' }
  });
}

function baseDomain(hostname: string): string {
  return hostname.toLowerCase().replace(/\.$/, '');
}

function isAllowedHost(hostname: string): boolean {
  const host = baseDomain(hostname);
  return ALLOWED_DOMAINS.some((domain) => host === domain || host.endsWith(`.${domain}`));
}

// Defence in depth: the allowlist already excludes these, but reject explicitly.
function isBlockedHost(hostname: string): boolean {
  const host = baseDomain(hostname);
  if (host === 'localhost' || host.endsWith('.localhost') || host.endsWith('.local') || host.endsWith('.internal')) return true;
  if (host === '::1' || host === '[::1]' || host === '0.0.0.0') return true;
  const ipv4 = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!ipv4) return false;
  const [a, b] = [Number(ipv4[1]), Number(ipv4[2])];
  if (a === 10 || a === 127 || a === 0) return true;
  if (a === 192 && b === 168) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 169 && b === 254) return true;
  return true;
}

function normalizeUrl(raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    throw new Error('That is not a valid URL.');
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error('Only http(s) listing URLs are supported.');
  }
  if (isBlockedHost(url.hostname)) {
    throw new Error('That host is not permitted.');
  }
  if (!isAllowedHost(url.hostname)) {
    throw new Error(`Only ${ALLOWED_DOMAINS.join(', ')} listings are supported.`);
  }
  for (const param of TRACKING_PARAMS) url.searchParams.delete(param);
  url.hash = '';
  return url;
}

async function fetchHtml(url: URL): Promise<string> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const response = await fetch(url.toString(), {
      redirect: 'follow',
      signal: controller.signal,
      headers: {
        'User-Agent': 'OUTLAND-COMPASS/0.2 (listing importer)',
        Accept: 'text/html,application/xhtml+xml'
      }
    });
    if (!response.ok) throw new Error(`Listing page responded with ${response.status}.`);

    const contentType = response.headers.get('content-type') ?? '';
    if (!/text\/html|application\/xhtml|text\/plain/i.test(contentType)) {
      throw new Error('That URL did not return an HTML listing page.');
    }
    if (isBlockedHost(new URL(response.url).hostname) || !isAllowedHost(new URL(response.url).hostname)) {
      throw new Error('Listing redirected to a host that is not permitted.');
    }

    const reader = response.body?.getReader();
    if (!reader) return '';
    const chunks: Uint8Array[] = [];
    let total = 0;
    while (total < MAX_RESPONSE_BYTES) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      total += value.byteLength;
    }
    await reader.cancel().catch(() => undefined);

    const buffer = new Uint8Array(Math.min(total, MAX_RESPONSE_BYTES));
    let offset = 0;
    for (const chunk of chunks) {
      const remaining = buffer.length - offset;
      if (remaining <= 0) break;
      buffer.set(chunk.subarray(0, Math.min(chunk.byteLength, remaining)), offset);
      offset += chunk.byteLength;
    }

    const charset = contentType.match(/charset=([\w-]+)/i)?.[1] ?? 'utf-8';
    try {
      return new TextDecoder(charset).decode(buffer);
    } catch {
      return new TextDecoder('utf-8').decode(buffer);
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error('Listing page took too long to respond.');
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

function decodeEntities(value: string): string {
  return value
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#0?39;|&apos;/gi, "'")
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)));
}

function clean(value: string | null | undefined): string | null {
  if (typeof value !== 'string') return null;
  const text = decodeEntities(value).replace(/\s+/g, ' ').trim();
  return text.length ? text : null;
}

function meta(html: string, key: string): string | null {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const tag = html.match(new RegExp(`<meta[^>]+(?:property|name)\\s*=\\s*["']${escaped}["'][^>]*>`, 'i'))?.[0];
  if (!tag) return null;
  return clean(tag.match(/content\s*=\s*["']([^"']*)["']/i)?.[1]);
}

function parseNumber(raw: unknown): number | null {
  if (typeof raw === 'number') return Number.isFinite(raw) ? raw : null;
  if (typeof raw !== 'string') return null;
  let text = raw.replace(/\s/g, '').replace(/[^\d.,]/g, '');
  if (!text) return null;

  const lastComma = text.lastIndexOf(',');
  const lastDot = text.lastIndexOf('.');
  if (lastComma > -1 && lastDot > -1) {
    text = lastComma > lastDot ? text.replace(/\./g, '').replace(',', '.') : text.replace(/,/g, '');
  } else if (lastComma > -1) {
    const parts = text.split(',');
    text = parts.length === 2 && parts[1].length <= 2 ? `${parts[0]}.${parts[1]}` : text.replace(/,/g, '');
  } else if (lastDot > -1) {
    const parts = text.split('.');
    text = parts.length === 2 && parts[1].length <= 2 ? `${parts[0]}.${parts[1]}` : text.replace(/\./g, '');
  }

  const value = Number(text);
  return Number.isFinite(value) ? value : null;
}

function collectJsonLd(value: unknown, out: Record<string, unknown>[]): void {
  if (Array.isArray(value)) {
    for (const entry of value) collectJsonLd(entry, out);
    return;
  }
  if (!value || typeof value !== 'object') return;
  const node = value as Record<string, unknown>;
  out.push(node);
  if (node['@graph']) collectJsonLd(node['@graph'], out);
}

function jsonLdNodes(html: string): Record<string, unknown>[] {
  const nodes: Record<string, unknown>[] = [];
  const pattern = /<script[^>]+type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(html))) {
    try {
      collectJsonLd(JSON.parse(decodeEntities(match[1].trim())), nodes);
    } catch {
      // Malformed JSON-LD is ignored rather than guessed at.
    }
  }
  return nodes;
}

function firstString(nodes: Record<string, unknown>[], keys: string[]): string | null {
  for (const node of nodes) {
    for (const key of keys) {
      const value = node[key];
      if (typeof value === 'string' && value.trim()) return clean(value);
    }
  }
  return null;
}

function jsonLdOffer(nodes: Record<string, unknown>[]): Record<string, unknown> | null {
  for (const node of nodes) {
    const offers = node['offers'];
    if (offers && typeof offers === 'object') {
      const offer = Array.isArray(offers) ? offers[0] : offers;
      if (offer && typeof offer === 'object') return offer as Record<string, unknown>;
    }
  }
  return null;
}

function jsonLdQuantity(nodes: Record<string, unknown>[], keys: string[]): number | null {
  for (const node of nodes) {
    for (const key of keys) {
      const value = node[key];
      if (typeof value === 'number' || typeof value === 'string') {
        const parsed = parseNumber(value);
        if (parsed !== null) return parsed;
      }
      if (value && typeof value === 'object') {
        const parsed = parseNumber((value as Record<string, unknown>)['value']);
        if (parsed !== null) return parsed;
      }
    }
  }
  return null;
}

function jsonLdAddress(nodes: Record<string, unknown>[]): string | null {
  for (const node of nodes) {
    const address = node['address'];
    if (typeof address === 'string' && address.trim()) return clean(address);
    if (address && typeof address === 'object') {
      const parts = ['streetAddress', 'addressLocality', 'addressRegion', 'addressCountry']
        .map((key) => (address as Record<string, unknown>)[key])
        .filter((part): part is string => typeof part === 'string' && part.trim().length > 0);
      if (parts.length) return clean(parts.join(', '));
    }
  }
  return null;
}

function detectCurrency(text: string): string | null {
  if (/€|\bEUR\b/i.test(text)) return 'EUR';
  if (/\bRSD\b|\bдин\b|\bdin\b/i.test(text)) return 'RSD';
  return null;
}

function findPrice(text: string): { price: number | null; currency: string | null } {
  const patterns = [
    /(?:€|\bEUR\b)\s*([\d][\d.,\s]{2,})/i,
    /([\d][\d.,\s]{2,})\s*(?:€|\bEUR\b)/i,
    /([\d][\d.,\s]{2,})\s*(?:RSD|дин\.?|din\.?)/i
  ];
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) {
      const price = parseNumber(match[1]);
      if (price !== null && price > 0) return { price, currency: detectCurrency(match[0]) };
    }
  }
  return { price: null, currency: null };
}

function findArea(text: string): number | null {
  const match = text.match(/([\d][\d.,\s]*)\s*(?:m²|m2|m\s*2|kvadrata|kvm)\b/i);
  if (!match) return null;
  const area = parseNumber(match[1]);
  return area !== null && area > 0 ? area : null;
}

function sourceNameFor(hostname: string): string | null {
  const host = baseDomain(hostname);
  if (host.endsWith('oglasi.rs')) return 'Oglasi.rs';
  if (host.endsWith('realitica.com')) return 'Realitica';
  if (host.endsWith('estitor.com')) return 'Estitor';
  if (host.endsWith('nekretnine.rs')) return 'Nekretnine.rs';
  return null;
}

function stripTags(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ');
}

// Oglasi.rs renders the target listing's own fields as "Label: value" pairs.
// Everything from the advertiser/related blocks onward is dropped so a
// recommended listing's price can never be read as this listing's price.
const OGLASI_TAIL_MARKERS = [
  /Informacije o ogla[sš]iva[cč]u/i,
  /Ostali oglasi ogla[sš]iva[cč]a/i,
  /Sli[cč]ni oglasi/i,
  /Preporu[cč]eni oglasi/i,
  /Izdvojeni oglasi/i
];

function oglasiListingText(html: string): string {
  const text = decodeEntities(stripTags(html));
  let cut = text.length;
  for (const marker of OGLASI_TAIL_MARKERS) {
    const index = text.search(marker);
    if (index > -1 && index < cut) cut = index;
  }
  return text.slice(0, cut);
}

const OGLASI_LABEL_STOP = 'Lokacija|Namena|Povr[sš]ina|Kvadratura|Struktura|Uknji[zž]|Dodatne informacije|Tekst oglasa|Cena|[SŠ]ifra|Agencijska|Broj pregleda|Obnovljen';

function oglasiPrice(text: string): { price: number | null; currency: string | null } {
  const match = text.match(new RegExp(`\\bCena\\s*:?\\s*([\\d][\\d.\\s]*(?:,\\d{1,2})?)\\s*(EUR|€|RSD|din\\.?)`, 'i'));
  if (!match) return { price: null, currency: null };
  const price = parseNumber(match[1]);
  if (price === null || price <= 0) return { price: null, currency: null };
  return { price, currency: detectCurrency(match[2]) };
}

function oglasiLocation(text: string): string | null {
  const match = text.match(new RegExp(`\\bLokacija\\s*:?\\s*(.{2,120}?)\\s*(?:${OGLASI_LABEL_STOP})\\s*:`, 'i'));
  const value = clean(match?.[1]);
  return value && !/^:/.test(value) ? value : null;
}

function oglasiArea(text: string): number | null {
  const match = text.match(/\b(?:Povr[sš]ina(?:\s+zemlji[sš]ta)?|Kvadratura)\s*:?\s*([\d][\d.,\s]*?)\s*(?:m²|m2)\b/i);
  if (!match) return null;
  const area = parseNumber(match[1]);
  return area !== null && area > 0 ? area : null;
}

function listingIdFor(url: URL): string | null {
  const host = baseDomain(url.hostname);
  const path = url.pathname;
  if (host.endsWith('realitica.com')) return path.match(/\/listing\/(\d+)/i)?.[1] ?? null;
  if (host.endsWith('estitor.com')) return path.match(/\/id-(\d+)/i)?.[1] ?? null;
  if (host.endsWith('nekretnine.rs')) return path.match(/\/oglasi\/(\d+)/i)?.[1] ?? null;
  if (host.endsWith('oglasi.rs')) {
    return path.match(/(\d{2}-\d{5,})/)?.[1] ?? url.searchParams.get('oglas') ?? null;
  }
  return null;
}

function parseListing(html: string, url: URL): ImportedListing {
  const nodes = jsonLdNodes(html);
  const offer = jsonLdOffer(nodes);
  const isOglasi = baseDomain(url.hostname).endsWith('oglasi.rs');
  const oglasiText = isOglasi ? oglasiListingText(html) : '';

  const ogTitle = meta(html, 'og:title');
  const ogDescription = meta(html, 'og:description');
  const title = firstString(nodes, ['name', 'headline']) ?? ogTitle ?? clean(html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1]);
  const description = firstString(nodes, ['description']) ?? ogDescription ?? meta(html, 'description');

  // Bounded scope on purpose: listing pages embed "similar property" panels, so
  // scanning the whole document would import a neighbouring listing's numbers.
  const primaryText = [title, description, ogTitle, ogDescription].filter(Boolean).join(' · ');

  let price = offer ? parseNumber(offer['price']) : null;
  let currency = offer && typeof offer['priceCurrency'] === 'string' ? String(offer['priceCurrency']).toUpperCase() : null;
  if (price === null) {
    const metaPrice = parseNumber(meta(html, 'product:price:amount'));
    if (metaPrice !== null) {
      price = metaPrice;
      currency = currency ?? clean(meta(html, 'product:price:currency'))?.toUpperCase() ?? null;
    }
  }
  if (price === null && isOglasi) {
    const found = oglasiPrice(oglasiText);
    price = found.price;
    currency = currency ?? found.currency;
  }
  if (price === null && !isOglasi) {
    const found = findPrice(primaryText);
    price = found.price;
    currency = currency ?? found.currency;
  }

  const area = jsonLdQuantity(nodes, ['floorSize', 'lotSize', 'area']) ?? (isOglasi ? oglasiArea(oglasiText) : null) ?? findArea(primaryText);
  const location = jsonLdAddress(nodes) ?? clean(meta(html, 'og:locality')) ?? (isOglasi ? oglasiLocation(oglasiText) : null);
  const image_url = extractMetaImageUrl(html, url, 'og:image')
    ?? extractMetaImageUrl(html, url, 'twitter:image')
    ?? extractJsonLdImageUrl(nodes, url);

  return {
    source_name: sourceNameFor(url.hostname),
    source_url: url.toString(),
    source_listing_id: listingIdFor(url),
    title,
    location,
    price,
    currency: price !== null ? currency ?? 'EUR' : currency,
    area_m2: area,
    description,
    image_url
  };
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (request.method !== 'POST') return json({ error: 'Use POST.' }, 405);

  const authorization = request.headers.get('Authorization');
  if (!authorization) return json({ error: 'Authentication required.' }, 401);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  if (!supabaseUrl || !anonKey) return json({ error: 'Importer is not configured.' }, 500);

  // Anon key + caller's JWT only; the service-role key is never used here.
  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false }
  });
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user) return json({ error: 'Authentication required.' }, 401);

  let rawUrl: string;
  try {
    const body = await request.json();
    rawUrl = typeof body?.url === 'string' ? body.url : '';
  } catch {
    return json({ error: 'Send a JSON body with a url field.' }, 400);
  }
  if (!rawUrl.trim()) return json({ error: 'Paste a listing URL first.' }, 400);

  try {
    const url = normalizeUrl(rawUrl);
    const html = await fetchHtml(url);
    return json(parseListing(html, url));
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Listing could not be imported.' }, 400);
  }
});