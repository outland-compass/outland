'use client';

import { useRef, useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';

type Kind = 'world' | 'theme' | 'franchise';
type Feedback = { type: 'success' | 'error'; text: string };

export function GuardedEditor({ universeId, universeSlug }: { universeId: string; universeSlug: string }) {
  const router = useRouter();
  const savingRef = useRef(false);
  const [kind, setKind] = useState<Kind>('world');
  const [slug, setSlug] = useState('');
  const [name, setName] = useState('');
  const [feedback, setFeedback] = useState<Feedback | null>(null);
  const [saving, setSaving] = useState(false);

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (savingRef.current) return;
    savingRef.current = true;
    setSaving(true);
    setFeedback(null);
    try {
      const response = await fetch('/api/studio/write?universe=' + encodeURIComponent(universeSlug), {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          entity: kind,
          input: { universeId, slug: slug.trim().toLowerCase(), name: name.trim(), status: 'draft', ...(kind === 'franchise' ? { canonVersion: 1 } : {}) }
        })
      });
      const result: { id?: string; error?: string } = await response.json();
      if (!response.ok) throw new Error(result.error ?? 'Save failed');
      if (!result.id) throw new Error('Save returned no ID');
      setFeedback({ type: 'success', text: 'Draft saved successfully. ID: ' + result.id });
      setSlug('');
      setName('');
      router.refresh();
    } catch (error) {
      setFeedback({ type: 'error', text: error instanceof Error ? error.message : 'Save failed' });
    } finally {
      savingRef.current = false;
      setSaving(false);
    }
  }

  return <form className="authoringPanel guardedEditor" onSubmit={save} aria-busy={saving}>
    <h2>Create draft</h2>
    <p className="muted">Universe: <strong>{universeSlug}</strong>. New records start as drafts. Server-side ownership validation is required.</p>
    <div className="formGrid">
      <label>Entity
        <select value={kind} disabled={saving} onChange={event => { setKind(event.target.value as Kind); setFeedback(null); }}>
          <option value="world">World</option>
          <option value="theme">Theme</option>
          <option value="franchise">Franchise</option>
        </select>
      </label>
      <label>Name
        <input disabled={saving} autoComplete="off" value={name} onChange={event => setName(event.target.value)} required maxLength={160} placeholder="e.g. River Mysteries" />
      </label>
    </div>
    <label>Slug
      <input disabled={saving} autoComplete="off" value={slug} onChange={event => setSlug(event.target.value.toLowerCase().replace(/\s+/g, '-'))} required pattern="[a-z0-9]+(-[a-z0-9]+)*" maxLength={120} placeholder="e.g. river-mysteries" />
    </label>
    <p className="muted">Use lowercase letters, numbers and hyphens. Slug must be unique within its scope.</p>
    <button className="button" type="submit" disabled={saving || !slug.trim() || !name.trim()}>{saving ? 'Saving draft…' : 'Create draft'}</button>
    {feedback && <p role={feedback.type === 'error' ? 'alert' : 'status'} className={feedback.type === 'error' ? 'formError' : 'formSuccess'}>{feedback.text}</p>}
  </form>;
}
