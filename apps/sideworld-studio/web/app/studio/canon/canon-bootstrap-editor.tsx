'use client';

import { FormEvent, useState } from 'react';

type Entity = 'universe' | 'franchise' | 'series' | 'lore' | 'rule';

async function save(entity: Entity, input: Record<string, unknown>) {
  const response = await fetch('/api/studio/write', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ entity, input })
  });

  const result = await response.json().catch(() => null) as { id?: string; error?: string } | null;
  if (!response.ok || !result?.id) {
    throw new Error(result?.error ?? 'Save failed');
  }
  return result.id;
}

function value(form: FormData, name: string) {
  return String(form.get(name) ?? '').trim();
}

export function CanonBootstrapEditor() {
  const [universeId, setUniverseId] = useState('');
  const [franchiseId, setFranchiseId] = useState('');
  const [seriesId, setSeriesId] = useState('');
  const [message, setMessage] = useState('');

  async function submit(entity: Entity, form: HTMLFormElement) {
    setMessage('');
    const data = new FormData(form);
    const input = Object.fromEntries(data.entries());

    try {
      const id = await save(entity, input);
      if (entity === 'universe') setUniverseId(id);
      if (entity === 'franchise') setFranchiseId(id);
      if (entity === 'series') setSeriesId(id);
      setMessage(`${entity} saved · ${id}`);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Save failed');
    }
  }

  function onSubmit(entity: Entity) {
    return async (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();
      await submit(entity, event.currentTarget);
    };
  }

  return (
    <section className="authoringStack">
      <p className="formMessage" role="status">{message}</p>

      <form className="authoringPanel" onSubmit={onSubmit('universe')}>
        <p className="eyebrow">1 · Universe</p>
        <h2>Universe identity</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <div className="formGrid">
          <input name="slug" placeholder="slug" defaultValue="beyond-the-atlas" required />
          <input name="name" placeholder="Name" defaultValue="BEYOND THE ATLAS" required />
          <select name="visibility" defaultValue="private">
            <option value="private">private</option>
            <option value="unlisted">unlisted</option>
            <option value="public">public</option>
          </select>
          <select name="status" defaultValue="draft">
            <option value="draft">draft</option>
            <option value="active">active</option>
            <option value="archived">archived</option>
          </select>
        </div>
        <textarea name="description" placeholder="Description" />
        <button className="button" type="submit">Save universe</button>
        {universeId && <code>{universeId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('franchise')}>
        <p className="eyebrow">2 · Franchise</p>
        <h2>Franchise container</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <input name="universeId" value={universeId} onChange={(e) => setUniverseId(e.target.value)} placeholder="Universe UUID" required />
        <div className="formGrid">
          <input name="slug" placeholder="slug" defaultValue="beyond-the-atlas" required />
          <input name="name" placeholder="Name" defaultValue="BEYOND THE ATLAS" required />
          <select name="status" defaultValue="draft">
            <option value="draft">draft</option>
            <option value="active">active</option>
            <option value="archived">archived</option>
          </select>
          <input name="canonVersion" type="number" min="1" defaultValue="1" />
        </div>
        <textarea name="description" placeholder="Description" />
        <button className="button" type="submit">Save franchise</button>
        {franchiseId && <code>{franchiseId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('series')}>
        <p className="eyebrow">3 · Series</p>
        <h2>Series</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <input name="franchiseId" value={franchiseId} onChange={(e) => setFranchiseId(e.target.value)} placeholder="Franchise UUID" required />
        <div className="formGrid">
          <input name="slug" placeholder="slug" defaultValue="the-lost-cartographers" required />
          <input name="name" placeholder="Name" defaultValue="The Lost Cartographers" required />
          <select name="status" defaultValue="draft">
            <option value="draft">draft</option>
            <option value="active">active</option>
            <option value="archived">archived</option>
          </select>
          <input name="sortOrder" type="number" min="1" defaultValue="100" />
        </div>
        <input name="themeId" placeholder="Theme UUID (optional)" />
        <textarea name="premise" placeholder="Premise" />
        <button className="button" type="submit">Save series</button>
        {seriesId && <code>{seriesId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('lore')}>
        <p className="eyebrow">4 · Lore</p>
        <h2>Lore fact</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <input name="franchiseId" value={franchiseId} onChange={(e) => setFranchiseId(e.target.value)} placeholder="Franchise UUID" required />
        <input name="seriesId" value={seriesId} onChange={(e) => setSeriesId(e.target.value)} placeholder="Series UUID (optional)" />
        <div className="formGrid">
          <input name="factKey" placeholder="fact key" defaultValue="unbroken-line" required />
          <select name="canonStatus" defaultValue="proposed">
            <option value="draft">draft</option>
            <option value="proposed">proposed</option>
            <option value="approved">approved</option>
            <option value="retired">retired</option>
          </select>
          <select name="visibility" defaultValue="internal">
            <option value="internal">internal</option>
            <option value="hidden">hidden</option>
            <option value="player_known">player known</option>
            <option value="public">public</option>
          </select>
          <input name="revealPhase" placeholder="Reveal phase (optional)" />
        </div>
        <textarea name="statement" defaultValue="The Unbroken Line is an overarching mystery, not a series." required />
        <button className="button" type="submit">Save lore fact</button>
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('rule')}>
        <p className="eyebrow">5 · Canon rule</p>
        <h2>AI / continuity guardrail</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <input name="franchiseId" value={franchiseId} onChange={(e) => setFranchiseId(e.target.value)} placeholder="Franchise UUID" required />
        <input name="seriesId" value={seriesId} onChange={(e) => setSeriesId(e.target.value)} placeholder="Series UUID (optional)" />
        <input name="characterId" placeholder="Character UUID (optional)" />
        <div className="formGrid">
          <input name="ruleType" placeholder="Rule type" defaultValue="continuity" required />
          <select name="severity" defaultValue="error">
            <option value="info">info</option>
            <option value="warning">warning</option>
            <option value="error">error</option>
          </select>
          <select name="status" defaultValue="active">
            <option value="draft">draft</option>
            <option value="active">active</option>
            <option value="retired">retired</option>
          </select>
        </div>
        <textarea name="ruleText" defaultValue="Runtime AI must not invent global canon." required />
        <button className="button" type="submit">Save canon rule</button>
      </form>
    </section>
  );
}
