import { CompassRepository } from './compass.repository';

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