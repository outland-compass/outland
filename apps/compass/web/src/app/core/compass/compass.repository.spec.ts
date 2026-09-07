import { CompassRepository, extractSourceImage } from './compass.repository';

type QueryResult<T> = { data: T | null; error: { code?: string; message: string } | null };

function retryableQuery<T>(results: QueryResult<T>[]) {
  let attempts = 0;
  const query: PromiseLike<QueryResult<T>> = {
    then(onfulfilled, onrejected) {
      const result = results[attempts++];
      return Promise.resolve(result).then(onfulfilled, onrejected);
    }
  };
  return { query, attempts: () => attempts };
}

describe('CompassRepository PostgREST error handling', () => {
  const repository = new CompassRepository({} as never);
  const data = (request: PromiseLike<QueryResult<string[]>>) =>
    (repository as unknown as { data: (value: PromiseLike<QueryResult<string[]>>) => Promise<string[]> }).data(request);

  it('retries a future-JWT PostgREST rejection once', async () => {
    vi.useFakeTimers();
    const request = retryableQuery<string[]>([
      { data: null, error: { code: 'PGRST303', message: 'JWT issued at future' } },
      { data: ['loaded'], error: null }
    ]);

    const result = data(request.query);
    await vi.advanceTimersByTimeAsync(750);

    await expect(result).resolves.toEqual(['loaded']);
    expect(request.attempts()).toBe(2);
    vi.useRealTimers();
  });

  it('does not retry unrelated PostgREST errors', async () => {
    const request = retryableQuery<string[]>([
      { data: null, error: { code: '42501', message: 'permission denied' } }
    ]);

    await expect(data(request.query)).rejects.toThrow('permission denied');
    expect(request.attempts()).toBe(1);
  });
});

describe('extractSourceImage', () => {
  it('extracts image_url from raw_payload', () => {
    const snapshot = {
      raw_payload: { image_url: 'https://example.com/image.jpg' }
    };
    expect(extractSourceImage(snapshot)).toBe('https://example.com/image.jpg');
  });

  it('returns null when snapshot is null', () => {
    expect(extractSourceImage(null)).toBeNull();
  });

  it('returns null when snapshot is not an object', () => {
    expect(extractSourceImage('string')).toBeNull();
    expect(extractSourceImage(123)).toBeNull();
  });

  it('returns null when raw_payload is missing', () => {
    const snapshot = { other_field: 'value' };
    expect(extractSourceImage(snapshot)).toBeNull();
  });

  it('returns null when raw_payload is not an object', () => {
    const snapshot = { raw_payload: 'not-an-object' };
    expect(extractSourceImage(snapshot)).toBeNull();
  });

  it('returns null when image_url is missing from raw_payload', () => {
    const snapshot = { raw_payload: { other_field: 'value' } };
    expect(extractSourceImage(snapshot)).toBeNull();
  });

  it('returns null when image_url is not a string', () => {
    const snapshot = { raw_payload: { image_url: 123 } };
    expect(extractSourceImage(snapshot)).toBeNull();

    const snapshot2 = { raw_payload: { image_url: null } };
    expect(extractSourceImage(snapshot2)).toBeNull();
  });

  it('returns null when image_url is an empty or whitespace string', () => {
    expect(extractSourceImage({ raw_payload: { image_url: '' } })).toBeNull();
    expect(extractSourceImage({ raw_payload: { image_url: '   ' } })).toBeNull();
  });
});