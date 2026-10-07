'use client';

import { FormEvent, useState } from 'react';

type Entity =
  | 'universe' | 'world' | 'theme'
  | 'franchise' | 'series' | 'character' | 'faction' | 'lore' | 'rule'
  | 'country' | 'city' | 'worldCity';

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

export function CanonBootstrapEditor() {
  const [universeId, setUniverseId] = useState('');
  const [worldId, setWorldId] = useState('');
  const [themeId, setThemeId] = useState('');
  const [franchiseId, setFranchiseId] = useState('');
  const [seriesId, setSeriesId] = useState('');
  const [characterId, setCharacterId] = useState('');
  const [cityId, setCityId] = useState('');
  const [message, setMessage] = useState('');

  async function submit(entity: Entity, form: HTMLFormElement) {
    setMessage('');
    const input = Object.fromEntries(new FormData(form).entries());

    try {
      const id = await save(entity, input);
      if (entity === 'universe') setUniverseId(id);
      if (entity === 'world') setWorldId(id);
      if (entity === 'theme') setThemeId(id);
      if (entity === 'franchise') setFranchiseId(id);
      if (entity === 'series') setSeriesId(id);
      if (entity === 'character') setCharacterId(id);
      if (entity === 'city') setCityId(id);
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
        <h2>Canonical Universe identity</h2>
        <p className="muted">BEYOND THE ATLAS is a franchise, not a Universe. Create or select its owning Universe here.</p>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <div className="formGrid">
          <input name="slug" placeholder="universe-slug" required />
          <input name="name" placeholder="Universe name" required />
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

      <form className="authoringPanel" onSubmit={onSubmit('world')}>
        <p className="eyebrow">2 · World</p>
        <h2>World</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <input name="universeId" value={universeId} onChange={(e) => setUniverseId(e.target.value)} placeholder="Universe UUID" required />
        <div className="formGrid">
          <input name="slug" placeholder="world-slug" required />
          <input name="name" placeholder="World name" required />
          <select name="status" defaultValue="draft">
            <option value="draft">draft</option>
            <option value="active">active</option>
            <option value="archived">archived</option>
          </select>
        </div>
        <textarea name="summary" placeholder="World summary" />
        <button className="button" type="submit">Save world</button>
        {worldId && <code>{worldId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('theme')}>
        <p className="eyebrow">3 · Theme</p>
        <h2>Creative identity</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <input name="universeId" value={universeId} onChange={(e) => setUniverseId(e.target.value)} placeholder="Universe UUID (optional for global theme)" />
        <div className="formGrid">
          <input name="slug" placeholder="theme-slug" required />
          <input name="name" placeholder="Theme name" required />
          <select name="status" defaultValue="draft">
            <option value="draft">draft</option>
            <option value="active">active</option>
            <option value="archived">archived</option>
          </select>
        </div>
        <textarea name="description" placeholder="Theme description" />
        <button className="button" type="submit">Save theme</button>
        {themeId && <code>{themeId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('franchise')}>
        <p className="eyebrow">4 · Franchise</p>
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
        <p className="eyebrow">5 · Series</p>
        <h2>Series</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <input name="franchiseId" value={franchiseId} onChange={(e) => setFranchiseId(e.target.value)} placeholder="Franchise UUID" required />
        <input name="themeId" value={themeId} onChange={(e) => setThemeId(e.target.value)} placeholder="Theme UUID (optional)" />
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
        <textarea name="premise" placeholder="Premise" />
        <button className="button" type="submit">Save series</button>
        {seriesId && <code>{seriesId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('character')}>
        <p className="eyebrow">6 · Character</p>
        <h2>Recurring character</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <input name="franchiseId" value={franchiseId} onChange={(e) => setFranchiseId(e.target.value)} placeholder="Franchise UUID" required />
        <div className="formGrid">
          <input name="slug" placeholder="character-slug" required />
          <input name="name" placeholder="Canonical name" required />
          <input name="displayName" placeholder="Display name (optional)" />
          <input name="role" placeholder="Role (optional)" />
          <input name="age" type="number" min="1" placeholder="Age (optional)" />
          <select name="canonStatus" defaultValue="draft">
            <option value="draft">draft</option>
            <option value="proposed">proposed</option>
            <option value="approved">approved</option>
            <option value="retired">retired</option>
          </select>
        </div>
        <textarea name="bio" placeholder="Short bio" />
        <button className="button" type="submit">Save character</button>
        {characterId && <code>{characterId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('faction')}>
        <p className="eyebrow">7 · Faction</p>
        <h2>Faction</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <input name="franchiseId" value={franchiseId} onChange={(e) => setFranchiseId(e.target.value)} placeholder="Franchise UUID" required />
        <div className="formGrid">
          <input name="slug" placeholder="faction-slug" required />
          <input name="name" placeholder="Faction name" required />
          <input name="factionType" placeholder="Type (optional)" />
          <select name="visibility" defaultValue="hidden">
            <option value="hidden">hidden</option>
            <option value="partial">partial</option>
            <option value="public">public</option>
          </select>
          <select name="canonStatus" defaultValue="draft">
            <option value="draft">draft</option>
            <option value="proposed">proposed</option>
            <option value="approved">approved</option>
            <option value="retired">retired</option>
          </select>
        </div>
        <textarea name="description" placeholder="Faction description" />
        <button className="button" type="submit">Save faction</button>
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('lore')}>
        <p className="eyebrow">8 · Lore</p>
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
        <p className="eyebrow">9 · Canon rule</p>
        <h2>AI / continuity guardrail</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <input name="franchiseId" value={franchiseId} onChange={(e) => setFranchiseId(e.target.value)} placeholder="Franchise UUID" required />
        <input name="seriesId" value={seriesId} onChange={(e) => setSeriesId(e.target.value)} placeholder="Series UUID (optional)" />
        <input name="characterId" value={characterId} onChange={(e) => setCharacterId(e.target.value)} placeholder="Character UUID (optional)" />
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

      <form className="authoringPanel" onSubmit={onSubmit('country')}>
        <p className="eyebrow">10 · Country</p>
        <h2>Geographic country</h2>
        <div className="formGrid">
          <input name="code" maxLength={2} defaultValue="RS" placeholder="ISO-2" required />
          <input name="name" defaultValue="Serbia" placeholder="Country name" required />
          <input name="defaultLocale" defaultValue="sr-RS" placeholder="Default locale" />
        </div>
        <button className="button" type="submit">Save country</button>
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('city')}>
        <p className="eyebrow">11 · City</p>
        <h2>Real-world city truth</h2>
        <input name="id" placeholder="Existing UUID (leave empty to create)" />
        <div className="formGrid">
          <input name="countryCode" maxLength={2} defaultValue="RS" placeholder="Country code" required />
          <input name="slug" defaultValue="novi-sad" placeholder="city-slug" required />
          <input name="name" defaultValue="Novi Sad" placeholder="City name" required />
          <input name="region" defaultValue="Vojvodina" placeholder="Region" />
          <input name="timezone" defaultValue="Europe/Belgrade" placeholder="Timezone" required />
          <input name="defaultLocale" defaultValue="sr-RS" placeholder="Default locale" required />
          <input name="latitude" type="number" step="any" placeholder="Latitude (optional)" />
          <input name="longitude" type="number" step="any" placeholder="Longitude (optional)" />
          <select name="status" defaultValue="draft">
            <option value="draft">draft</option>
            <option value="active">active</option>
            <option value="archived">archived</option>
          </select>
          <select name="verificationStatus" defaultValue="unverified">
            <option value="unverified">unverified</option>
            <option value="partially_verified">partially verified</option>
            <option value="verified">verified</option>
            <option value="disputed">disputed</option>
          </select>
        </div>
        <button className="button" type="submit">Save city</button>
        {cityId && <code>{cityId}</code>}
      </form>

      <form className="authoringPanel" onSubmit={onSubmit('worldCity')}>
        <p className="eyebrow">12 · World ↔ City</p>
        <h2>Attach city to world</h2>
        <input name="worldId" value={worldId} onChange={(e) => setWorldId(e.target.value)} placeholder="World UUID" required />
        <input name="cityId" value={cityId} onChange={(e) => setCityId(e.target.value)} placeholder="City UUID" required />
        <select name="relationshipType" defaultValue="story">
          <option value="primary">primary</option>
          <option value="story">story</option>
          <option value="operational">operational</option>
          <option value="expansion">expansion</option>
        </select>
        <button className="button" type="submit">Save world-city relation</button>
      </form>
    </section>
  );
}
