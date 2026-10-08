'use client';
import { useEffect } from 'react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';

type Universe = { id: string; slug: string; name: string };
export function UniverseSelector({ universes, selected }: { universes: Universe[]; selected: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const search = useSearchParams();
  useEffect(() => {
    const saved = localStorage.getItem('sideworld.studio.universe');
    if (!search.has('universe') && saved && saved !== selected && universes.some(u => u.slug === saved)) {
      const p = new URLSearchParams(search.toString());
      p.set('universe', saved);
      router.replace(pathname + '?' + p.toString());
    }
  }, [pathname, router, search, selected, universes]);
  return <label>Universe <select aria-label="Active universe" value={selected} onChange={event => {
    const slug = event.target.value;
    if (!universes.some(u => u.slug === slug)) return;
    localStorage.setItem('sideworld.studio.universe', slug);
    const p = new URLSearchParams(search.toString());
    p.set('universe', slug);
    for (const key of ['city', 'world', 'series', 'lore']) p.delete(key);
    router.push(pathname + '?' + p.toString());
    router.refresh();
  }}>{universes.map(u => <option key={u.id} value={u.slug}>{u.name}</option>)}</select></label>;
}
