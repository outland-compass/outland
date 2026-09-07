import { routes } from './app.routes';

describe('OUTLAND routes', () => {
  const compassLayout = routes.find(
    (route) => route.path === '' && route.canActivate?.length === 1 && route.children?.length
  );

  it('defines public home and RAFTER routes', () => {
    const publicHome = routes.find(
      (route) => route.path === '' && route.pathMatch === 'full' && !route.canActivate
    );
    const rafter = routes.find((route) => route.path === 'rafter' && !route.canActivate);

    expect(publicHome).toBeDefined();
    expect(rafter).toBeDefined();
  });

  it('keeps COMPASS operational routes inside the protected layout', () => {
    expect(compassLayout).toBeDefined();

    const childPaths = compassLayout?.children?.map((route) => route.path) ?? [];

    for (const path of ['radar', 'candidates/:id', 'compare', 'due-diligence', 'worlds']) {
      expect(childPaths).toContain(path);
    }
  });

  it('protects the COMPASS layout with auth', () => {
    expect(compassLayout?.canActivate?.length).toBe(1);
  });
});
