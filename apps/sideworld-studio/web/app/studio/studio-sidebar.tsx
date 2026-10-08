'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { usePathname, useSearchParams } from 'next/navigation';

const sections = [
  { label: 'Authoring', links: [{ label: 'Canon Editor', path: '/studio/canon' }, { label: 'City Knowledge', path: '/studio/city' }] },
  { label: 'Explore', links: [{ label: 'Canon Inspector', path: '/studio/inspector' }, { label: 'Canon Context', path: '/studio/context' }] }
];

export function StudioSidebar({ universeSlug }: { universeSlug?: string }) {
  const searchParams = useSearchParams();
  const pathname = usePathname();
  const currentUniverse = universeSlug ?? searchParams.get('universe') ?? undefined;
  const [collapsed, setCollapsed] = useState(false);
  const [expanded, setExpanded] = useState<Record<string, boolean>>({ Authoring: true, Explore: true });
  useEffect(() => {
    try {
      setCollapsed(window.localStorage.getItem('sideworld.studio.sidebar.collapsed') === 'true');
    } catch { /* Storage can be unavailable in privacy mode. */ }
  }, []);
  function toggleCollapsed() {
    setCollapsed(value => {
      const next = !value;
      try { window.localStorage.setItem('sideworld.studio.sidebar.collapsed', String(next)); } catch { /* Optional preference. */ }
      return next;
    });
  }
  const scoped = (path: string) => currentUniverse ? path + '?universe=' + encodeURIComponent(currentUniverse) : path;

  return <aside className={collapsed ? 'studioSidebar collapsed' : 'studioSidebar'}>
    <div className="sidebarTop">
      {!collapsed && <Link href={scoped('/studio')} className="brand small">SIDE<span>WORLD</span></Link>}
      <button type="button" className="sidebarToggle" aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'} aria-expanded={!collapsed} onClick={toggleCollapsed}>{collapsed ? '»' : '«'}</button>
    </div>
    {!collapsed && <p className="eyebrow">Studio navigation</p>}
    <nav aria-label="Studio navigation">
      <Link className="sidebarHome" href={scoped('/studio')} aria-current={pathname === '/studio' ? 'page' : undefined} title="Dashboard">{collapsed ? '⌂' : 'Dashboard'}</Link>
      {sections.map(section => <div className="sidebarSection" key={section.label}>
        <button type="button" className="sidebarSectionToggle" title={section.label} aria-expanded={!!expanded[section.label] && !collapsed} onClick={() => { if (collapsed) { setCollapsed(false); try { window.localStorage.setItem('sideworld.studio.sidebar.collapsed', 'false'); } catch { /* Optional preference. */ } setExpanded(current => ({ ...current, [section.label]: true })); } else { setExpanded(current => ({ ...current, [section.label]: !current[section.label] })); } }}>
          <span>{collapsed ? section.label.charAt(0) : section.label}</span><span aria-hidden="true">{collapsed ? '›' : expanded[section.label] ? '⌄' : '›'}</span>
        </button>
        {!collapsed && expanded[section.label] && <div className="sidebarLinks">{section.links.map(link => <Link key={link.path} href={scoped(link.path)} aria-current={pathname === link.path ? 'page' : undefined}>{link.label}</Link>)}</div>}
      </div>)}
    </nav>
  </aside>;
}
