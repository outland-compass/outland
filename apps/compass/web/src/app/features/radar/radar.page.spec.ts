import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { CompassRepository, RadarRow, Signal } from '../../core/compass/compass.repository';
import { RoleService } from '../../core/compass/role.service';
import RadarPage, { mapRadarSources } from './radar.page';

describe('RadarPage thumbnail mapping', () => {
  it('maps image_url by candidate_id while preserving listing URLs', () => {
    const result = mapRadarSources([{ candidate_id: 'candidate-a', source_url: 'https://listing/a', image_url: 'https://image/a.jpg' }]);
    expect(result.urls).toEqual({ 'candidate-a': 'https://listing/a' });
    expect(result.images).toEqual({ 'candidate-a': 'https://image/a.jpg' });
  });

  it('keeps the first valid image for each candidate', () => {
    const result = mapRadarSources([
      { candidate_id: 'candidate-a', source_url: null, image_url: '   ' },
      { candidate_id: 'candidate-a', source_url: 'https://listing/a', image_url: 'https://image/a-first.jpg' },
      { candidate_id: 'candidate-a', source_url: 'https://listing/a-2', image_url: 'https://image/a-second.jpg' },
      { candidate_id: 'candidate-b', source_url: null, image_url: null }
    ]);
    expect(result.images).toEqual({ 'candidate-a': 'https://image/a-first.jpg' });
    expect(result.images['candidate-b']).toBeUndefined();
    expect(result.urls).toEqual({ 'candidate-a': 'https://listing/a' });
  });

  it('marks only the candidate whose image failed', () => {
    const candidateImgFailed = signal<Record<string, boolean>>({});
    (RadarPage.prototype.onCandidateImgError as Function).call({ candidateImgFailed }, 'candidate-a');
    expect(candidateImgFailed()).toEqual({ 'candidate-a': true });
    expect(candidateImgFailed()['candidate-b']).toBeUndefined();
  });
});

describe('RadarPage thumbnail rendering', () => {
  const row = (id: string, worldCode = 'GREENHILL'): RadarRow => ({ id, title: `Candidate ${id}`, world_code: worldCode, settlement: 'Test location' } as RadarRow);
  const signal = (id: string, image_url?: string): Signal => ({ id, raw_payload: image_url ? { image_url } : {}, raw_title: `Signal ${id}`, status: 'NEW' } as Signal);

  async function createPage(rows: RadarRow[], sources: { candidate_id: string; source_url: string | null; image_url: string | null }[], signals: Signal[] = []) {
    const repository = { radar: vi.fn().mockResolvedValue(rows), worlds: vi.fn().mockResolvedValue([]), signals: vi.fn().mockResolvedValue(signals), sourceUrls: vi.fn().mockResolvedValue(sources) };
    const roles = { canAnalyze: true, load: vi.fn().mockResolvedValue(undefined) };
    await TestBed.configureTestingModule({ imports: [RadarPage], providers: [provideRouter([]), { provide: CompassRepository, useValue: repository }, { provide: RoleService, useValue: roles }] }).compileComponents();
    const fixture = TestBed.createComponent(RadarPage);
    await fixture.whenStable();
    fixture.detectChanges();
    return { fixture, page: fixture.componentInstance };
  }

  it('renders an image when image_url is available', async () => {
    const { fixture } = await createPage([row('candidate-a')], [{ candidate_id: 'candidate-a', source_url: null, image_url: 'https://image/a.jpg' }]);
    expect(fixture.nativeElement.querySelector('.thumb img')?.getAttribute('src')).toBe('https://image/a.jpg');
  });

  it('renders the fixed placeholder when no image_url is available', async () => {
    const { fixture } = await createPage([row('candidate-a')], [{ candidate_id: 'candidate-a', source_url: null, image_url: null }]);
    expect(fixture.nativeElement.querySelector('.thumb-empty')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('.thumb img')).toBeNull();
  });

  it('shows a candidate-specific placeholder after an image error', async () => {
    const { fixture } = await createPage([row('candidate-a'), row('candidate-b')], [
      { candidate_id: 'candidate-a', source_url: null, image_url: 'https://image/a.jpg' },
      { candidate_id: 'candidate-b', source_url: null, image_url: 'https://image/b.jpg' }
    ]);
    const images = fixture.nativeElement.querySelectorAll('.thumb img') as NodeListOf<HTMLImageElement>;
    images[0].dispatchEvent(new Event('error'));
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelectorAll('.thumb-empty').length).toBe(1);
    expect(fixture.nativeElement.querySelectorAll('.thumb img').length).toBe(1);
    expect(fixture.nativeElement.querySelector('.thumb img')?.getAttribute('src')).toBe('https://image/b.jpg');
  });

  it('recomputes candidate results when the World filter changes', async () => {
    const { fixture, page } = await createPage([row('greenhill', 'GREENHILL'), row('work-a', 'OUTLAND_WORK'), row('work-b', 'OUTLAND_WORK')], []);
    expect(page.filtered().length).toBe(3);
    page.world = 'OUTLAND_WORK';
    fixture.detectChanges();
    expect(page.filtered().map((candidate) => candidate.id)).toEqual(['work-a', 'work-b']);
    expect(fixture.nativeElement.querySelectorAll('.candidate-row').length).toBe(2);
  });

  it('recomputes candidate results when search changes', async () => {
    const { fixture, page } = await createPage([row('alpha'), row('beta')], []);
    page.search = 'beta';
    fixture.detectChanges();
    expect(page.filtered().map((candidate) => candidate.id)).toEqual(['beta']);
    expect(fixture.nativeElement.querySelectorAll('.candidate-row').length).toBe(1);
  });

  it('renders a Signal image from raw_payload.image_url', async () => {
    const { fixture, page } = await createPage([], [], [signal('signal-a', 'https://image/a.jpg')]);
    page.panel.set('signals'); fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.signal-thumb img')?.getAttribute('src')).toBe('https://image/a.jpg');
  });

  it('renders a fixed Signal thumbnail slot without an image', async () => {
    const { fixture, page } = await createPage([], [], [signal('signal-a')]);
    page.panel.set('signals'); fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.signal-thumb')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('.signal-thumb img')).toBeNull();
  });

  it('keeps the Signal slot after an image error', async () => {
    const { fixture, page } = await createPage([], [], [signal('signal-a', 'https://image/a.jpg')]);
    page.panel.set('signals'); fixture.detectChanges();
    fixture.nativeElement.querySelector('.signal-thumb img').dispatchEvent(new Event('error')); fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.signal-thumb')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('.signal-thumb img')).toBeNull();
  });

  it('does not suppress another Signal after one image fails', async () => {
    const { fixture, page } = await createPage([], [], [signal('signal-a', 'https://image/a.jpg'), signal('signal-b', 'https://image/b.jpg')]);
    page.panel.set('signals'); fixture.detectChanges();
    fixture.nativeElement.querySelectorAll('.signal-thumb img')[0].dispatchEvent(new Event('error')); fixture.detectChanges();
    expect(fixture.nativeElement.querySelectorAll('.signal-thumb').length).toBe(2);
    expect(fixture.nativeElement.querySelectorAll('.signal-thumb img').length).toBe(1);
    expect(fixture.nativeElement.querySelector('.signal-thumb img')?.getAttribute('src')).toBe('https://image/b.jpg');
  });
});
