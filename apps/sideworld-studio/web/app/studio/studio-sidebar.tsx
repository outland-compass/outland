'use client';

import Link from 'next/link';
import { useState } from 'react';

const sections = [
  { label: 'Authoring', links: [{ label: 'Canon Editor', path: '/studio/canon' }, { label: 'City Knowledge', path: '/studio/city' }] },
  { label: 'Explore', links: [{ label: 'Canon Inspector', path: '/studio/inspector' }, { label: 'Canon Context', path: '/studio/context' }] }
];

export function StudioSidebar({ universeSlug }: { universeSlug?: string }) {
  const [collapsed, setCollapsed] = useState(false);
  const [expanded, setExpanded] = useState<Record<string, boolean>>({ Authoring: true, Explore: true });
  const scoped = (path: string) => universeSlug ? path + '?universe=' + encodeURIComponent(universeSlug) : path;

  return <aside className={collapsed ? 'studioSidebar collapsed' : 'studioSidebar'}>
    <div className="sidebarTop">
      {!collapsed && <Link href={scoped('/studio')} className="brand small">SIDE<span>WORLD</span></Link>}
      <button type="button" className="sidebarToggle" aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'} aria-expanded={!collapsed} onClick={() => setCollapsed(value => !value)}>{collapsed ? '»' : '«'}</button>
    </div>
    {!collapsed && <p className="eyebrow">Studio navigation</p>}
    <nav aria-label="Studio navigation">
      <Link className="sidebarHome" href={scoped('/studio')} title="Dashboard">{collapsed ? '⌂' : 'Dashboard'}</Link>
      {sections.map(section => <div className="sidebarSection" key={section.label}>
        <button type="button" className="sidebarSectionToggle" title={section.label} aria-expanded={!!expanded[section.label] && !collapsed} onClick={() => { if (collapsed) { setCollapsed(false); setExpanded(current => ({ ...current, [section.label]: true })); } else { setExpanded(current => ({ ...current, [section.label]: !current[section.label] })); } }}>
          <span>{collapsed ? section.label.charAt(0) : section.label}</span><span aria-hidden="true">{collapsed ? '›' : expanded[section.label] ? '⌄' : '›'}</span>
        </button>
        {!collapsed && expanded[section.label] && <div className="sidebarLinks">{section.links.map(link => <Link key={link.path} href={scoped(link.path)}>{link.label}</Link>)}</div>}
      </div>)}
    </nav>
  </aside>;
}
