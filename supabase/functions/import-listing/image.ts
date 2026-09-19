export function normalizeImageUrl(value: unknown, baseUrl: URL): string | null {
  if (typeof value !== 'string' || !value.trim()) return null;
  try {
    const url = new URL(value.trim(), baseUrl);
    return url.protocol === 'http:' || url.protocol === 'https:' ? url.href : null;
  } catch {
    return null;
  }
}

function clean(value: string): string | null {
  const text = value
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .trim();
  return text || null;
}

function metaImage(html: string, key: string): string | null {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const tag = html.match(new RegExp(`<meta[^>]+(?:property|name)\\s*=\\s*["']${escaped}["'][^>]*>`, 'i'))?.[0];
  const value = tag?.match(/content\s*=\s*["']([^"']*)["']/i)?.[1];
  return value ? clean(value) : null;
}

export function extractMetaImageUrl(html: string, baseUrl: URL, key: string): string | null {
  return normalizeImageUrl(metaImage(html, key), baseUrl);
}

function jsonLdImageValue(value: unknown, baseUrl: URL): string | null {
  if (typeof value === 'string') return normalizeImageUrl(value, baseUrl);
  if (Array.isArray(value)) {
    for (const item of value) {
      const image = jsonLdImageValue(item, baseUrl);
      if (image) return image;
    }
    return null;
  }
  if (value && typeof value === 'object') {
    const image = value as Record<string, unknown>;
    return jsonLdImageValue(image['url'] ?? image['contentUrl'], baseUrl);
  }
  return null;
}

export function extractJsonLdImageUrl(nodes: Record<string, unknown>[], baseUrl: URL): string | null {
  for (const node of nodes) {
    const image = jsonLdImageValue(node['image'], baseUrl);
    if (image) return image;
  }
  return null;
}


function imageAttribute(tag: string, name: string): string | null {
  const escaped = name.replace(/[.*+?^$\{\}()|[\]\\]/g, '\\$&');
  const value = tag.match(new RegExp(`\\b${escaped}\\s*=\\s*["']([^"']+)["']`, 'i'))?.[1];
  return value ? clean(value) : null;
}

function srcsetFirst(value: string | null, baseUrl: URL): string | null {
  if (!value) return null;
  for (const candidate of value.split(',')) {
    const raw = candidate.trim().split(/\s+/)[0];
    const image = normalizeImageUrl(raw, baseUrl);
    if (image) return image;
  }
  return null;
}

export function extractHtmlImageUrl(html: string, baseUrl: URL): string | null {
  const tags = html.match(/<img\b[^>]*>/gi) ?? [];
  for (const tag of tags) {
    const haystack = tag.toLowerCase();
    if (/logo|icon|avatar|profile|banner|sprite|placeholder/.test(haystack)) continue;
    const direct = ['data-src', 'data-lazy-src', 'data-original', 'src']
      .map((name) => normalizeImageUrl(imageAttribute(tag, name), baseUrl))
      .find((value): value is string => Boolean(value));
    if (direct) return direct;
    const responsive = srcsetFirst(imageAttribute(tag, 'data-srcset') ?? imageAttribute(tag, 'srcset'), baseUrl);
    if (responsive) return responsive;
  }
  return null;
}
