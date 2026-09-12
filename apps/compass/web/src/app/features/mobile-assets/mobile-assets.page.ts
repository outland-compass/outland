import { NgClass } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { CompassRepository, RadarRow } from '../../core/compass/compass.repository';

type SourceMap = Record<string, string>;

type RadarSource = { candidate_id: string; source_url: string | null; image_url: string | null };

function mapSourceImages(sources: RadarSource[]): SourceMap {
  const images: SourceMap = {};
  for (const source of sources) {
    const image = source.image_url?.trim();
    if (image && !images[source.candidate_id]) images[source.candidate_id] = image;
  }
  return images;
}

@Component({
  imports: [NgClass, RouterLink],
  template: `
    <section class="page mobile-assets-page">
      <header class="page-header">
        <div>
          <p class="eyebrow">COMPASS / NETWORK ASSETS</p>
          <h1>MOBILE ASSETS</h1>
          <p>Shared OUTLAND assets that move between Worlds.</p>
        </div>
      </header>

      @if (loading()) {
        <div class="state">Loading Mobile Assets...</div>
      } @else if (error()) {
        <div class="state error">{{ error() }}</div>
      } @else {
        <section class="program-card">
          <div class="program-copy">
            <div class="program-title"><span class="world">WANDERER</span><span class="type-pill">CAMPERVAN</span></div>
            <h2>WANDERER ACQUISITION RADAR</h2>
            <p>Find a beautiful, professionally converted, four-season camper that strengthens the whole OUTLAND network.</p>
            <div class="target-strip">
              <span><b>Target</b> €25–40k</span>
              <span><b>Exceptional</b> ≤€45k</span>
              <span><b>Roof</b> Fixed high</span>
              <span><b>AWD</b> Bonus</span>
            </div>
          </div>
          <div class="program-kpis">
            <div><strong>{{ activeCount() }}</strong><span>ACTIVE</span></div>
            <div><strong>{{ shortlistCount() }}</strong><span>SHORTLIST</span></div>
            <div><strong>{{ ddCount() }}</strong><span>DD</span></div>
          </div>
        </section>

        @if (benchmark()) {
          <section class="benchmark">
            <div class="benchmark-label">★ CURRENT BENCHMARK</div>
            <a [routerLink]="['/candidates', benchmark()!.id]" class="benchmark-card">
              <div class="hero" [class.hero-empty]="!benchmarkImage() || imageFailed()[benchmark()!.id!]">
                @if (benchmarkImage() && !imageFailed()[benchmark()!.id!]) {
                  <img [src]="benchmarkImage()" [alt]="benchmark()!.title" (error)="onImageError(benchmark()!.id!)">
                }
              </div>
              <div class="benchmark-copy">
                <span class="world">{{ benchmark()!.world_code }}</span>
                <h2>{{ benchmark()!.title }}</h2>
                <p>{{ location(benchmark()!) }}</p>
                <div class="benchmark-metrics">
                  <div><span>ASKING</span><strong>{{ money(benchmark()!.asking_price, benchmark()!.currency) }}</strong></div>
                  <div><span>COMPASS</span><strong>{{ number(benchmark()!.compass_score) }}</strong></div>
                  <div><span>CONFIDENCE</span><strong>{{ percent(benchmark()!.confidence_percent) }}</strong></div>
                </div>
              </div>
              <span class="badge" [ngClass]="badge(benchmark()!.recommendation)">{{ benchmark()!.recommendation }}</span>
            </a>
          </section>
        }

        <section class="radar-section">
          <div class="section-head"><div><p class="eyebrow">WANDERER</p><h2>CANDIDATES</h2></div><span>{{ wandererRows().length }} tracked</span></div>
          @if (wandererRows().length) {
            <div class="candidate-grid">
              @for (row of wandererRows(); track row.id) {
                <a class="candidate-card" [routerLink]="['/candidates', row.id]">
                  <div class="candidate-image" [class.hero-empty]="!row.id || !sourceImages()[row.id] || imageFailed()[row.id]">
                    @if (row.id && sourceImages()[row.id] && !imageFailed()[row.id]) {
                      <img [src]="sourceImages()[row.id]" [alt]="row.title" loading="lazy" (error)="onImageError(row.id)">
                    }
                  </div>
                  <div class="candidate-body">
                    <div class="candidate-top"><span class="status">{{ row.status }}</span><span class="score">{{ number(row.compass_score) }}</span></div>
                    <h3>{{ row.title }}</h3>
                    <p>{{ location(row) }}</p>
                    <div class="candidate-bottom"><strong>{{ money(row.asking_price, row.currency) }}</strong><span class="badge" [ngClass]="badge(row.recommendation)">{{ row.recommendation }}</span></div>
                  </div>
                </a>
              }
            </div>
          } @else {
            <div class="empty-state">
              <p class="eyebrow">RADAR READY</p>
              <h2>No WANDERER candidates yet.</h2>
              <p>Activate the WANDERER search profile and promote the first verified camper signal to start the benchmark.</p>
            </div>
          }
        </section>
      }
    </section>
  `,
  styleUrl: './mobile-assets.page.scss'
})
export default class MobileAssetsPage {
  readonly repo = inject(CompassRepository);
  readonly allRows = signal<RadarRow[]>([]);
  readonly sourceImages = signal<SourceMap>({});
  readonly imageFailed = signal<Record<string, boolean>>({});
  readonly loading = signal(true);
  readonly error = signal('');

  readonly wandererRows = computed(() => this.allRows().filter((row) => row.world_code === 'WANDERER').sort((a, b) => this.rank(b) - this.rank(a)));
  readonly benchmark = computed(() => this.wandererRows().find((row) => ['SHORTLIST', 'DD', 'NEGOTIATION'].includes(row.status ?? '')) ?? this.wandererRows()[0] ?? null);
  readonly benchmarkImage = computed(() => { const id = this.benchmark()?.id; return id ? this.sourceImages()[id] ?? null : null; });

  constructor() { void this.load(); }

  async load() {
    try {
      this.loading.set(true);
      const rows = await this.repo.radar();
      this.allRows.set(rows);
      const ids = rows.filter((row) => row.world_code === 'WANDERER').map((row) => row.id).filter((id): id is string => !!id);
      const sources = await this.repo.sourceUrls(ids);
      this.sourceImages.set(mapSourceImages(sources));
    } catch (error) {
      this.error.set(error instanceof Error ? error.message : 'Unable to load Mobile Assets.');
    } finally {
      this.loading.set(false);
    }
  }

  activeCount() { return this.wandererRows().filter((row) => !['ACQUIRED', 'REJECTED', 'ARCHIVED', 'SOLD'].includes(row.status ?? '')).length; }
  shortlistCount() { return this.wandererRows().filter((row) => row.status === 'SHORTLIST').length; }
  ddCount() { return this.wandererRows().filter((row) => row.status === 'DD').length; }
  rank(row: RadarRow) { return ({ HOT: 600, STRONG: 500, WATCH: 400, LOW: 300, UNSCORED: 100, BLOCKED: -100 }[row.recommendation ?? ''] ?? 0) + (row.compass_score ?? 0); }
  location(row: RadarRow) { return row.settlement || row.municipality || row.region || 'Location not recorded'; }
  money(value: number | null, currency: string | null = 'EUR') { return value == null ? '—' : new Intl.NumberFormat('en-IE', { style: 'currency', currency: currency ?? 'EUR', maximumFractionDigits: 0 }).format(value); }
  number(value: number | null) { return value == null ? '—' : Math.round(value).toString(); }
  percent(value: number | null) { return value == null ? '—' : `${Math.round(value)}%`; }
  badge(value: string | null) { return `badge-${(value ?? 'UNSCORED').toLowerCase()}`; }
  onImageError(id: string) { this.imageFailed.update((state) => ({ ...state, [id]: true })); }
}
