import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { CompassRepository, RadarRow } from '../../core/compass/compass.repository';
import { RoleService } from '../../core/compass/role.service';
import RadarPage, { mapRadarSources } from './radar.page';

describe('RadarPage thumbnail mapping', () => {
  it('maps image_url by candidate_id while preserving listing URLs', () => {
    const result = mapRadarSources([
      { candidate_id: 'candidate-a', source_url: 'https://listing/a', image_url: 'https://image/a.jpg' }
    ]);

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
  const row = (id: string): RadarRow => ({
    id,
    title: `Candidate ${id}`,
    world_code: 'GREENHILL',
    settlement: 'Test location'
  } as RadarRow);

  async function createPage(rows: RadarRow[], sources: { candidate_id: string; source_url: string | null; image_url: string | null }[]) {
    const repository = {
      radar: vi.fn().mockResolvedValue(rows),
      worlds: vi.fn().mockResolvedValue([]),
      signals: vi.fn().mockResolvedValue([]),
      sourceUrls: vi.fn().mockResolvedValue(sources)
    };
    const roles = { canAnalyze: true, load: vi.fn().mockResolvedValue(undefined) };
    await TestBed.configureTestingModule({
      imports: [RadarPage],
      providers: [
        provideRouter([]),
        { provide: CompassRepository, useValue: repository },
        { provide: RoleService, useValue: roles }
      ]
    }).compileComponents();
    const fixture = TestBed.createComponent(RadarPage);
    await fixture.whenStable();
    fixture.detectChanges();
    return { fixture, page: fixture.componentInstance };
  }

  it('renders an image when image_url is available', async () => {
    const { fixture } = await createPage([row('candidate-a')], [
      { candidate_id: 'candidate-a', source_url: null, image_url: 'https://image/a.jpg' }
    ]);

    expect(fixture.nativeElement.querySelector('.thumb img')?.getAttribute('src')).toBe('https://image/a.jpg');
  });

  it('renders the fixed placeholder when no image_url is available', async () => {
    const { fixture } = await createPage([row('candidate-a')], [
      { candidate_id: 'candidate-a', source_url: null, image_url: null }
    ]);

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
});
