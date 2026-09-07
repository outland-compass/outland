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
