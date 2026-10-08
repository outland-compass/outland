import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');

test('Studio navigation is shared by all Studio pages', () => {
  const layout = read('../app/studio/layout.tsx');
  assert.match(layout, /<StudioSidebar\s*\/>/);
  assert.match(layout, /<Suspense/);
  assert.match(layout, /\{children\}/);
});

test('sidebar can collapse and its sections expand independently', () => {
  const source = read('../app/studio/studio-sidebar.tsx');
  assert.match(source, /setCollapsed/);
  assert.match(source, /setExpanded/);
  assert.match(source, /aria-expanded/);
  assert.match(source, /aria-current/);
  assert.match(source, /usePathname/);
});

test('sidebar retains universe context on route changes', () => {
  const source = read('../app/studio/studio-sidebar.tsx');
  assert.match(source, /useSearchParams/);
  assert.match(source, /searchParams\.get\('universe'\)/);
  assert.match(source, /encodeURIComponent\(currentUniverse\)/);
});

test('guarded editor prevents concurrent edits and refreshes on success', () => {
  const source = read('../app/studio/canon/guarded-editor.tsx');
  assert.match(source, /disabled=\{saving\}/);
  assert.match(source, /router\.refresh\(\)/);
  assert.match(source, /if \(!result\.id\)/);
  assert.match(source, /status: 'draft'/);
});

test('guarded writes remain disabled unless explicitly enabled', () => {
  const source = read('../app/studio/canon/page.tsx');
  assert.match(source, /SIDEWORLD_STUDIO_GUARDED_WRITES === 'enabled'/);
  assert.match(source, /enabled && selected/);
});

test('sidebar remembers its collapsed state with safe storage fallback', () => {
  const source = read('../app/studio/studio-sidebar.tsx');
  assert.match(source, /sideworld\.studio\.sidebar\.collapsed/);
  assert.match(source, /window\.localStorage\.getItem/);
  assert.match(source, /window\.localStorage\.setItem/);
  assert.match(source, /catch \{/);
});

test('mobile hamburger opens a dismissible, full navigation drawer', () => {
  const source = read('../app/studio/studio-sidebar.tsx');
  const styles = read('../app/globals.css');
  assert.match(source, /studioHamburger/);
  assert.match(source, /aria-controls="studio-navigation-drawer"/);
  assert.match(source, /studioMobileBackdrop/);
  assert.match(source, /setMobileOpen\(false\)/);
  assert.match(source, /visuallyCollapsed = collapsed && !mobileOpen/);
  assert.match(styles, /@media\(max-width:850px\)/);
  assert.match(styles, /\.studioSidebar\.mobileOpen/);
});
