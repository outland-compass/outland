import { routes } from './app.routes';

describe('COMPASS routes', () => {
  it('defines each protected Property Radar placeholder route', () => {
    const paths = routes.map((route) => route.path);

    expect(paths).toContain('radar');
    expect(paths).toContain('candidates/:id');
    expect(paths).toContain('compare');
    expect(paths).toContain('due-diligence');
    expect(paths).toContain('worlds');
  });
});
