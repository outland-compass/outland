'use client';

import { useState } from 'react';

type Kind = 'world' | 'theme' | 'franchise';

export function GuardedEditor({ universeId, universeSlug }: { universeId: string; universeSlug: string }) {
  const [kind, setKind] = useState<Kind>('world');
  const [slug, setSlug] = useState('');
  const [name, setName] = useState('');
  const [message, setMessage] = useState('');
  const [saving, setSaving] = useState(false);

  async function save(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setMessage('');
    try {
      const response = await fetch('/api/studio/write?universe=' + encodeURIComponent(universeSlug), {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          entity: kind,
          input: { universeId, slug, name, status: 'draft', ...(kind === 'franchise' ? { canonVersion: 1 } : {}) }
        })
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error ?? 'Save failed');
      setMessage('Draft saved. ID: ' + result.id);
      setSlug('');
      setName('');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Save failed');
    } finally {
      setSaving(false);
    }
  }

  return <form onSubmit={save}>
    <h2>Create draft in {universeSlug}</h2>
    <p>All saves use server-side transactional ownership validation.</p>
    <label>Entity <select value={kind} onChange={event => setKind(event.target.value as Kind)}>
      <option value="world">World</option><option value="theme">Theme</option><option value="franchise">Franchise</option>
    </select></label>
    <label>Slug <input value={slug} onChange={event => setSlug(event.target.value)} required pattern="[a-z0-9]+(-[a-z0-9]+)*" maxLength={120}/></label>
    <label>Name <input value={name} onChange={event => setName(event.target.value)} required maxLength={160}/></label>
    <button className="button" type="submit" disabled={saving}>{saving ? 'Saving…' : 'Create draft'}</button>
    {message && <p role="status">{message}</p>}
  </form>;
}
