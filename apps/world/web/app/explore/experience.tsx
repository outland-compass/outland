'use client';

import { useState } from 'react';

type View = 'threshold' | 'worlds' | 'rafter' | 'passport' | 'mystery' | 'ending';
type Discovery = 'front' | 'river';

const discoveryCopy: Record<Discovery, { kicker: string; title: string; copy: string }> = {
  front: {
    kicker: 'Arrival',
    title: 'Front Deck',
    copy: 'Every journey starts by crossing a threshold.'
  },
  river: {
    kicker: 'The River Room',
    title: 'Inside, outside',
    copy: 'A room made to keep the river close.'
  }
};

export function Experience() {
  const [view, setView] = useState<View>('threshold');
  const [discoveries, setDiscoveries] = useState<Set<Discovery>>(new Set());
  const [sheet, setSheet] = useState<Discovery | null>(null);
  const [mysteryTouched, setMysteryTouched] = useState(false);
  const [idea, setIdea] = useState(false);

  function discover(value: Discovery) {
    setDiscoveries((current) => new Set(current).add(value));
    setSheet(value);
  }

  return (
    <main className="experience">
      {view === 'threshold' && (
        <section className="screen centerScreen">
          <div className="thresholdLine" aria-hidden="true" />
          <p className="eyebrow">Key accepted</p>
          <h1>Welcome,<br />Explorer.</h1>
          <p className="heroLine">Some places are found.<br /><em>Others find you.</em></p>
          <button className="primaryButton" onClick={() => setView('worlds')}>Enter OUTLAND</button>
        </section>
      )}

      {view === 'worlds' && (
        <section className="screen worldsScreen">
          <header className="screenHeader"><p className="smallWordmark">OUTLAND</p></header>
          <div className="worldsIntro"><p className="eyebrow">The Worlds</p><h1>The map is only beginning.</h1></div>
          <article className="worldCard">
            <img src="/media/rafter-hero.webp" alt="RAFTER floating on the river at blue hour" fetchPriority="high" />
            <div className="worldCardCopy"><p className="eyebrow">World 001</p><h2>RAFTER</h2><p>A World on the river.</p><button className="primaryButton" onClick={() => setView('rafter')}>Enter RAFTER</button></div>
          </article>
          <div className="sealedWorlds" aria-label="Future Worlds">
            {[1, 2, 3].map((number) => <div className="sealedWorld" key={number}><span>✦</span>Coming later</div>)}
          </div>
        </section>
      )}

      {view === 'rafter' && (
        <section className="screen rafterScreen">
          <button className="backButton" onClick={() => setView('worlds')} aria-label="Back to Worlds">←</button>
          <div className="rafterHero">
            <img src="/media/rafter-hero.webp" alt="RAFTER, a compact floating catamaran World" />
            <div className="rafterTitle"><p className="eyebrow">World 001</p><h1>RAFTER</h1><p>A World on the river.</p></div>
            <button className="hotspot frontHotspot" onClick={() => discover('front')} aria-label="Discover the Front Deck">1</button>
            <button className="hotspot riverHotspot" onClick={() => discover('river')} aria-label="Discover the River Room">2</button>
            <button className="hotspot passportHotspot" onClick={() => setView('passport')} aria-label="Discover the Passport">3</button>
            <button className="hotspot mysteryHotspot" onClick={() => setView('mystery')} aria-label="Discover Mystery 001">?</button>
            <div className="rafterFooter"><span>{discoveries.size} signals discovered</span><button onClick={() => setView('ending')}>Finish exploring</button></div>
          </div>
          {sheet && (
            <aside className="discoverySheet" aria-live="polite">
              <button onClick={() => setSheet(null)} aria-label="Close">×</button>
              <p className="eyebrow">{discoveryCopy[sheet].kicker}</p>
              <h2>{discoveryCopy[sheet].title}</h2>
              <p>{discoveryCopy[sheet].copy}</p>
            </aside>
          )}
        </section>
      )}

      {view === 'passport' && (
        <section className="screen detailScreen">
          <button className="backButton" onClick={() => setView('rafter')} aria-label="Back to RAFTER">←</button>
          <div className="passportVisual"><img src="/media/passport.webp" alt="OUTLAND Explorer Passport concept" loading="lazy" decoding="async" /></div>
          <div className="detailCopy"><p className="eyebrow">Explorer object</p><h1>Your Passport</h1><p>Opens paths.</p><p>Remembers where you’ve been.</p><p>Carries discoveries between Worlds.</p><button className="primaryButton" onClick={() => setView('rafter')}>Keep exploring</button></div>
        </section>
      )}

      {view === 'mystery' && (
        <section className="screen centerScreen mysteryScreen">
          <button className="backButton" onClick={() => setView('rafter')} aria-label="Back to RAFTER">←</button>
          <p className="eyebrow">Mystery #001</p><h1>Locked</h1>
          <p className="heroLine">Something is hidden in RAFTER.</p>
          <button className="mysterySignal" onClick={() => setMysteryTouched(true)} aria-label="Touch the hidden signal"><span style={{ display: 'block', transform: 'rotate(-45deg)' }}>✦</span></button>
          <p className="signalResponse">{mysteryTouched ? 'Not yet. But it noticed you.' : 'Touch the signal.'}</p>
          <button className="primaryButton" onClick={() => setView('rafter')}>Return to RAFTER</button>
        </section>
      )}

      {view === 'ending' && (
        <section className="screen centerScreen endingScreen">
          <span className="endingMark">✦</span><p className="eyebrow">You’re early</p>
          <h1>OUTLAND isn’t finished.</h1><p className="heroLine">Which is good.<br />You get to help build it.</p>
          <blockquote>What should exist in OUTLAND?</blockquote>
          <button className="primaryButton amberButton" onClick={() => setIdea(true)}>I have an idea</button>
          {idea && <p className="tellDarko">Tell Darko.</p>}
          <button className="secondaryButton" onClick={() => setView('worlds')}>Explore again</button>
        </section>
      )}
    </main>
  );
}
