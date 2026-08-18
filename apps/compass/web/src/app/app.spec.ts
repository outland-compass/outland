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

  it('protects each operational route', () => {
    for (const path of ['radar', 'candidates/:id', 'compare', 'due-diligence', 'worlds']) {
      expect(routes.find((route) => route.path === path)?.canActivate?.length).toBe(1);
    }
  });
});
