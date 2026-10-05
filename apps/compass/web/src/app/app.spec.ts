import { routes } from './app.routes';

describe('OUTLAND routes', () => {
  const compassLayout = routes.find(
    (route) => route.path === '' && route.canActivate?.length === 1 && route.children?.length
  );

  it('defines the public home without a visitor World route', () => {
    const publicHome = routes.find(
      (route) => route.path === '' && route.pathMatch === 'full' && !route.canActivate
    );
    expect(publicHome).toBeDefined();
    expect(routes.find((route) => route.path === 'rafter')).toBeUndefined();
  });

  it('keeps COMPASS operational routes inside the protected layout', () => {
    expect(compassLayout).toBeDefined();

    const childPaths = compassLayout?.children?.map((route) => route.path) ?? [];

    for (const path of ['radar', 'candidates/:id', 'compare', 'due-diligence', 'worlds']) {
      expect(childPaths).toContain(path);
    }
  });

  it('keeps password recovery pages public', () => {
    for (const path of ['sign-in', 'forgot-password', 'reset-password']) {
      const route = routes.find((candidate) => candidate.path === path);
      expect(route).toBeDefined();
      expect(route?.canActivate).toBeUndefined();
    }
  });

  it('protects the COMPASS layout with auth', () => {
    expect(compassLayout?.canActivate?.length).toBe(1);
  });
});
