import { describe, expect, it } from 'vitest';
import { extractJsonLdImageUrl, extractMetaImageUrl, normalizeImageUrl } from '../../../../../../../supabase/functions/import-listing/image';

const listingUrl = new URL('https://example.com/listings/42');

describe('import-listing image extraction', () => {
  it('extracts an absolute og:image URL', () => {
    expect(extractMetaImageUrl('<meta property="og:image" content="https://cdn.example.com/house.jpg">', listingUrl, 'og:image'))
      .toBe('https://cdn.example.com/house.jpg');
  });

  it('resolves a relative og:image URL against the listing URL', () => {
    expect(extractMetaImageUrl('<meta property="og:image" content="/media/house.jpg">', listingUrl, 'og:image'))
      .toBe('https://example.com/media/house.jpg');
  });

  it('uses twitter:image when Open Graph metadata is absent', () => {
    expect(extractMetaImageUrl('<meta name="twitter:image" content="https://cdn.example.com/twitter.jpg">', listingUrl, 'twitter:image'))
      .toBe('https://cdn.example.com/twitter.jpg');
  });

  it('extracts a JSON-LD string image', () => {
    expect(extractJsonLdImageUrl([{ image: 'https://cdn.example.com/string.jpg' }], listingUrl))
      .toBe('https://cdn.example.com/string.jpg');
  });

  it('extracts the first valid image from a JSON-LD array', () => {
    expect(extractJsonLdImageUrl([{ image: ['http://[invalid', '/media/array.jpg'] }], listingUrl))
      .toBe('https://example.com/media/array.jpg');
  });

  it('extracts a JSON-LD object image URL', () => {
    expect(extractJsonLdImageUrl([{ image: { contentUrl: '/media/object.jpg' } }], listingUrl))
      .toBe('https://example.com/media/object.jpg');
  });

  it('ignores malformed and unsupported image URLs', () => {
    expect(normalizeImageUrl('javascript:alert(1)', listingUrl)).toBeNull();
    expect(extractJsonLdImageUrl([{ image: 'http://[invalid' }, { image: 'ftp://example.com/image.jpg' }], listingUrl)).toBeNull();
  });

  it('returns null when no image metadata exists', () => {
    expect(extractMetaImageUrl('<title>Listing</title>', listingUrl, 'og:image')).toBeNull();
    expect(extractJsonLdImageUrl([{ name: 'Listing' }], listingUrl)).toBeNull();
  });
});
