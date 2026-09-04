import { DatePipe, NgClass } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { CompassRepository, DdItem, extractSourceImage } from '../../core/compass/compass.repository';
import { RoleService } from '../../core/compass/role.service';
import { Tables } from '../../core/supabase/database.types';

type Candidate = Tables<{ schema: 'land' }, 'candidates'>;
type CandidateStatus = Candidate['status'];
type Evidence = Tables<{ schema: 'land' }, 'evidence_items'>;

@Component({
  imports: [DatePipe, FormsModule, NgClass, RouterLink],
  template: `
    <section class="page">
      @if (loading()) {
        <div class="state">Loading decision file...</div>
      } @else if (error()) {
        <div class="state error">{{ error() }}</div>
      } @else if (candidate()) {
        <a routerLink="/radar" class="back">← Radar</a>
        @if (heroImage() && !imgFailed()) {
          <img class="hero-image" [src]="heroImage()" alt="" (error)="onImgError()">
        }
        <header class="page-header">
          <div>
            <p class="eyebrow">{{ radar()?.world_code }}</p>
            <h1>{{ candidate()?.title }}</h1>
            <p>{{ candidate()?.settlement || candidate()?.municipality || candidate()?.region || 'Location unknown' }} · {{ candidate()?.status }}</p>
            @if (sourceUrl()) {
              <a [href]="sourceUrl()" target="_blank" rel="noopener noreferrer" class="source-link">VIEW ORIGINAL LISTING ↗</a>
            }
          </div>
          <span class="badge" [ngClass]="'badge-'+(radar()?.recommendation || 'unscored').toLowerCase()">{{ radar()?.recommendation }}</span>
        </header>

        @if (actionError()) { <div class="state error compact">{{ actionError() }}</div> }
        @if (actionSuccess()) { <div class="state success compact">{{ actionSuccess() }}</div> }

        <div class="metrics">
          <article><span>COMPASS</span><strong>{{ number(radar()?.compass_score) }}</strong><b>{{ radar()?.recommendation }}</b></article>
          <article><span>CONFIDENCE</span><strong>{{ percent(radar()?.confidence_percent) }}</strong><b>{{ (radar()?.critical_unknown_count || 0) > 0 ? 'NEEDS EVIDENCE' : 'EVIDENCE MATURE' }}</b></article>
          <article><span>ASKING</span><strong>{{ money(candidate()?.asking_price) }}</strong><b>{{ area(candidate()?.area_m2) }}</b></article>
          <article><span>PHASE 1</span><strong>{{ money(radar()?.total_phase1_capital) }}</strong><b>capital</b></article>
        </div>

        <section class="panel">
          <div class="panel-header"><h2>CANDIDATE</h2><span class="muted">Minimal operational record</span></div>
          <form class="candidate-form" (ngSubmit)="saveCandidate()">
            <label>Title<input [(ngModel)]="edit.title" name="candidate-title" required [disabled]="!roles.canAnalyze || busy()"></label>
            <label>Status<select [(ngModel)]="edit.status" name="candidate-status" [disabled]="!roles.canAnalyze || busy()"><option [ngValue]="candidate()?.status">{{ candidate()?.status }}</option>@for(status of allowedStatuses(); track status){<option [ngValue]="status">{{ status }}</option>}</select></label>
            <label>Asking price<input [(ngModel)]="edit.asking_price" name="asking-price" type="number" min="0" [disabled]="!roles.canAnalyze || busy()"></label>
            <label>Area m²<input [(ngModel)]="edit.area_m2" name="area" type="number" min="1" [disabled]="!roles.canAnalyze || busy()"></label>
            <label>Target offer<input [(ngModel)]="edit.target_offer" name="target-offer" type="number" min="0" [disabled]="!roles.canAnalyze || busy()"></label>
            <label class="wide">Next action<input [(ngModel)]="edit.next_action" name="next-action" [disabled]="!roles.canAnalyze || busy()"></label>
            <button class="primary" [disabled]="!roles.canAnalyze || busy() || !edit.title">SAVE CANDIDATE</button>
          </form>
        </section>

        <div class="detail">
          <div>
            <section class="panel">
              <div class="panel-header"><h2>DUE DILIGENCE</h2><span class="muted">{{ ddItems().length }} tasks</span></div>
              @for (item of ddItems(); track item.id) {
                <div class="dd-item">
                  <div><b>{{ item.title }}</b><small>{{ item.category }} · {{ item.severity }} @if(item.due_date){· due {{ item.due_date | date:'dd MMM yyyy' }}}</small></div>
                  <select [(ngModel)]="item.status" [name]="'dd-status-'+item.id" [disabled]="!roles.canAnalyze || busy()">
                    <option>OPEN</option><option>IN_PROGRESS</option><option>VERIFIED</option><option>FAILED</option><option>NOT_APPLICABLE</option>
                  </select>
                  <button class="quiet" (click)="saveDd(item)" [disabled]="!roles.canAnalyze || busy()">SAVE</button>
                </div>
              } @empty { <p class="muted">No due-diligence tasks yet.</p> }
              <form class="stack-form" (ngSubmit)="addDd()">
                <h3>ADD TASK</h3>
                <div class="form-grid">
                  <label>Title<input [(ngModel)]="newDd.title" name="dd-title" required [disabled]="!roles.canAnalyze || busy()"></label>
                  <label>Category<input [(ngModel)]="newDd.category" name="dd-category" required [disabled]="!roles.canAnalyze || busy()"></label>
                  <label>Severity<select [(ngModel)]="newDd.severity" name="dd-severity" [disabled]="!roles.canAnalyze || busy()"><option>INFO</option><option>IMPORTANT</option><option>GATE</option></select></label>
                  <label>Due date<input [(ngModel)]="newDd.due_date" name="dd-due" type="date" [disabled]="!roles.canAnalyze || busy()"></label>
                </div>
                <label>Next step<input [(ngModel)]="newDd.next_step" name="dd-next" [disabled]="!roles.canAnalyze || busy()"></label>
                <button class="quiet" [disabled]="!roles.canAnalyze || busy() || !newDd.title.trim() || !newDd.category.trim()">ADD DD TASK</button>
              </form>
            </section>

            <section class="panel">
              <div class="panel-header"><h2>EVALUATION</h2>@if(!latest()){<button class="primary" (click)="start()" [disabled]="!roles.canAnalyze || busy()">START EVALUATION</button>}</div>
              @for(dimension of dimensions();track dimension.dimension){<div class="row"><b>{{dimension.dimension}}</b><strong>{{number(dimension.dimension_score)}}</strong><small>{{percent(dimension.dimension_confidence)}} confidence · {{dimension.unknown_count || 0}} unknown</small></div>}@empty{<p class="muted">No evaluation snapshot yet.</p>}
              @for(item of items();track item.id){<div class="criterion"><span>{{item.dimension}} · {{item.criterion_label}}</span><input [(ngModel)]="item.score" type="number" min="0" max="100" placeholder="UNKNOWN" [disabled]="!roles.canAnalyze || busy()"><input [(ngModel)]="item.confidence_percent" type="number" min="0" max="100" [disabled]="!roles.canAnalyze || busy()"><select [(ngModel)]="item.evidence_state" [disabled]="!roles.canAnalyze || busy()"><option>UNKNOWN</option><option>CLAIMED</option><option>OBSERVED</option><option>VERIFIED</option></select><button class="quiet" (click)="saveItem(item)" [disabled]="!roles.canAnalyze || busy()">SAVE</button></div>}
            </section>
            <section class="panel"><h2>GATES</h2>@for(gate of gates();track gate.id){<div class="gate"><div><b>{{gate.gate_label}}</b><small>{{gate.category}} @if(gate.is_critical){· CRITICAL}</small></div><select [(ngModel)]="gate.state" (change)="saveGate(gate)" [disabled]="!roles.canAnalyze || busy()"><option>UNKNOWN</option><option>PASS</option><option>FAIL</option><option>NOT_APPLICABLE</option></select></div>}</section>
          </div>

          <div>
            <section class="panel"><h2>COMMERCIAL</h2><dl><dt>Price / m²</dt><dd>{{money(candidate()?.price_per_m2)}}</dd><dt>Target offer</dt><dd>{{money(candidate()?.target_offer)}}</dd><dt>Likely purchase</dt><dd>{{money(economics()?.likely_purchase_price)}}</dd><dt>Base revenue</dt><dd>{{money(economics()?.annual_revenue_base)}}</dd></dl></section>
            <section class="panel"><h2>WHY COMPASS LIKES IT</h2>@for(item of evaluation()?.why_compass_likes_it || [];track item){<p>• {{item}}</p>}@empty{<p class="muted">No structured rationale.</p>}<h2>CONCERNS</h2>@for(item of evaluation()?.concerns || [];track item){<p class="concern">• {{item}}</p>}@empty{<p class="muted">No recorded concerns.</p>}</section>
            <section class="panel">
              <h2>EVIDENCE</h2>
              @for(item of evidence();track item.id){<p><b>{{item.title}}</b>@if(item.source_url){ · <a [href]="item.source_url" target="_blank" rel="noopener noreferrer">source ↗</a>}<small>{{item.evidence_type}} · {{item.verification_state}} @if(item.dd_item_id){ · {{ddTitle(item.dd_item_id)}} }</small></p>}@empty{<p class="muted">No evidence recorded.</p>}
              <form class="stack-form" (ngSubmit)="addEvidence()">
                <h3>ADD EVIDENCE</h3>
                <label>Title<input [(ngModel)]="newEvidence.title" name="evidence-title" required [disabled]="!roles.canEvidence || busy()"></label>
                <label>Source URL<input [(ngModel)]="newEvidence.source_url" name="evidence-url" type="url" [disabled]="!roles.canEvidence || busy()"></label>
                <label>Statement<textarea [(ngModel)]="newEvidence.statement" name="evidence-statement" [disabled]="!roles.canEvidence || busy()"></textarea></label>
                <div class="form-grid">
                  <label>Type<select [(ngModel)]="newEvidence.evidence_type" name="evidence-type" [disabled]="!roles.canEvidence || busy()"><option>SELLER_STATEMENT</option><option>LISTING</option><option>DOCUMENT</option><option>REGISTRY</option><option>PROFESSIONAL_OPINION</option><option>PHOTO</option><option>SITE_VISIT</option><option>MAP</option><option>EXTERNAL_URL</option><option>OTHER</option></select></label>
                  <label>Verification<select [(ngModel)]="newEvidence.verification_state" name="verification-state" [disabled]="!roles.canEvidence || busy()"><option>UNVERIFIED</option><option>PARTIALLY_VERIFIED</option><option>VERIFIED</option><option>DISPUTED</option></select></label>
                </div>
                <label>DD task<select [(ngModel)]="newEvidence.dd_item_id" name="evidence-dd" [disabled]="!roles.canEvidence || busy()"><option [ngValue]="null">Candidate-level</option>@for(item of ddItems();track item.id){<option [ngValue]="item.id">{{item.title}}</option>}</select></label>
                <button class="quiet" [disabled]="!roles.canEvidence || busy() || !newEvidence.title.trim()">ADD EVIDENCE</button>
              </form>
            </section>
            <section class="panel"><h2>NOTES</h2><form (ngSubmit)="note()"><textarea [(ngModel)]="newNote" name="note" placeholder="Add investment note" [disabled]="!roles.canEvidence || busy()"></textarea><button class="quiet" [disabled]="!newNote.trim() || !roles.canEvidence || busy()">ADD NOTE</button></form>@for(item of notes();track item.id){<p>{{item.body}}<small>{{item.created_at | date:'dd MMM yyyy'}}</small></p>}</section>
          </div>
        </div>
      }
    </section>
  `,
  styleUrl: './candidate.page.scss'
})
export default class CandidatePage {
  readonly repo = inject(CompassRepository);
  readonly roles = inject(RoleService);
  readonly id = inject(ActivatedRoute).snapshot.paramMap.get('id')!;
  readonly loading = signal(true);
  readonly error = signal('');
  readonly actionError = signal('');
  readonly actionSuccess = signal('');
  readonly busy = signal(false);
  readonly candidate = signal<Candidate | null>(null);
  readonly radar = signal<Tables<{ schema: 'land' }, 'v_candidate_radar'> | null>(null);
  readonly gates = signal<Tables<{ schema: 'land' }, 'candidate_gates'>[]>([]);
  readonly latest = signal<Tables<{ schema: 'land' }, 'v_candidate_latest_evaluation'> | null>(null);
  readonly evaluation = signal<Tables<{ schema: 'land' }, 'evaluations'> | null>(null);
  readonly dimensions = signal<Tables<{ schema: 'land' }, 'v_evaluation_dimension_scores'>[]>([]);
  readonly items = signal<Tables<{ schema: 'land' }, 'evaluation_items'>[]>([]);
  readonly economics = signal<Tables<{ schema: 'land' }, 'candidate_economics'> | null>(null);
  readonly notes = signal<Tables<{ schema: 'land' }, 'notes'>[]>([]);
  readonly evidence = signal<Evidence[]>([]);
  readonly ddItems = signal<DdItem[]>([]);
  readonly sources = signal<Tables<{ schema: 'land' }, 'candidate_sources'>[]>([]);
  readonly sourceUrl = computed(() => this.sources().find(s => s.source_url)?.source_url ?? null);
  readonly heroImage = computed(() => { for (const s of this.sources()) { const img = extractSourceImage(s.source_snapshot); if (img) return img; } return null; });
  readonly imgFailed = signal(false);
  readonly allowedStatuses = computed(() => this.transitions[this.candidate()?.status ?? 'NEW'] ?? []);

  edit = { title: '', status: 'NEW' as CandidateStatus, asking_price: null as number | null, area_m2: null as number | null, target_offer: null as number | null, next_action: '' as string | null };
  newDd = { title: '', category: 'LEGAL', severity: 'IMPORTANT' as DdItem['severity'], due_date: '', next_step: '' };
  newEvidence = { title: '', source_url: '', statement: '', evidence_type: 'EXTERNAL_URL' as Evidence['evidence_type'], verification_state: 'UNVERIFIED' as Evidence['verification_state'], dd_item_id: null as string | null };
  newNote = '';

  private readonly transitions: Record<CandidateStatus, CandidateStatus[]> = {
    NEW: ['REVIEWED', 'REJECTED', 'ARCHIVED'], REVIEWED: ['SHORTLIST', 'REJECTED', 'ARCHIVED'], SHORTLIST: ['DD', 'REVIEWED', 'REJECTED', 'ARCHIVED'],
    DD: ['NEGOTIATION', 'SHORTLIST', 'REJECTED', 'ARCHIVED'], NEGOTIATION: ['ACQUIRED', 'DD', 'REJECTED', 'ARCHIVED'], ACQUIRED: ['SOLD'],
    REJECTED: ['REVIEWED', 'ARCHIVED'], ARCHIVED: ['REVIEWED'], SOLD: ['ARCHIVED']
  };

  constructor() { void this.load(); void this.roles.load(); }

  async load() {
    try {
      this.loading.set(true); this.error.set('');
      const [c, r, g, e, n, v, s, d] = await Promise.all([this.repo.candidate(this.id), this.repo.radarCandidate(this.id), this.repo.gates(this.id), this.repo.economics(this.id), this.repo.notes(this.id), this.repo.evidence(this.id), this.repo.sources(this.id), this.repo.ddItems(this.id)]);
      const l = await this.repo.latestEvaluation(this.id) as Tables<{ schema: 'land' }, 'v_candidate_latest_evaluation'> | null;
      this.candidate.set(c); this.radar.set(r); this.gates.set(g); this.economics.set(e); this.notes.set(n); this.evidence.set(v); this.sources.set(s); this.ddItems.set(d); this.latest.set(l);
      this.edit = { title: c.title, status: c.status, asking_price: c.asking_price, area_m2: c.area_m2, target_offer: c.target_offer, next_action: c.next_action };
      if (l?.evaluation_id) { const [x, dimensions, items] = await Promise.all([this.repo.evaluation(l.evaluation_id), this.repo.dimensions(l.evaluation_id), this.repo.evaluationItems(l.evaluation_id)]); this.evaluation.set(x); this.dimensions.set(dimensions); this.items.set(items); }
    } catch (e) { this.error.set(this.message(e, 'Candidate could not load.')); }
    finally { this.loading.set(false); }
  }

  async saveCandidate() { await this.mutate('Candidate saved.', () => this.repo.updateCandidate(this.id, { title: this.edit.title.trim(), status: this.edit.status, asking_price: this.edit.asking_price, area_m2: this.edit.area_m2, target_offer: this.edit.target_offer, next_action: this.edit.next_action?.trim() || null })); }
  async addDd() { await this.mutate('DD task added.', () => this.repo.createDdItem({ candidate_id: this.id, title: this.newDd.title.trim(), category: this.newDd.category.trim(), severity: this.newDd.severity, due_date: this.newDd.due_date || null, next_step: this.newDd.next_step.trim() || null }), () => { this.newDd = { title: '', category: 'LEGAL', severity: 'IMPORTANT', due_date: '', next_step: '' }; }); }
  async saveDd(item: DdItem) { await this.mutate('DD task saved.', () => this.repo.updateDdItem(item.id, { status: item.status })); }
  async addEvidence() { await this.mutate('Evidence added.', () => this.repo.addEvidence({ candidate_id: this.id, title: this.newEvidence.title.trim(), statement: this.newEvidence.statement.trim() || null, source_url: this.newEvidence.source_url.trim() || null, evidence_type: this.newEvidence.evidence_type, verification_state: this.newEvidence.verification_state, dd_item_id: this.newEvidence.dd_item_id }), () => { this.newEvidence = { title: '', source_url: '', statement: '', evidence_type: 'EXTERNAL_URL', verification_state: 'UNVERIFIED', dd_item_id: null }; }); }
  async start() { await this.mutate('Evaluation started.', () => this.repo.startEvaluation(this.id)); }
  async saveItem(item: Tables<{ schema: 'land' }, 'evaluation_items'>) { await this.mutate('Evaluation item saved.', () => this.repo.updateEvaluationItem(item.id, { score: item.score, confidence_percent: item.confidence_percent, evidence_state: item.evidence_state })); }
  async saveGate(gate: Tables<{ schema: 'land' }, 'candidate_gates'>) { await this.mutate('Gate saved.', () => this.repo.updateGate(gate.id, { state: gate.state })); }
  async note() { const body = this.newNote.trim(); await this.mutate('Note added.', () => this.repo.addNote({ candidate_id: this.id, body }), () => { this.newNote = ''; }); }

  ddTitle(id: string) { return this.ddItems().find(item => item.id === id)?.title ?? 'DD task'; }
  money(v: number | null | undefined) { return v == null ? '—' : new Intl.NumberFormat('en-IE', { style: 'currency', currency: this.candidate()?.currency || 'EUR' }).format(v); }
  area(v: number | null | undefined) { return v == null ? '—' : `${new Intl.NumberFormat('en-IE').format(v)} m²`; }
  number(v: number | null | undefined) { return v == null ? 'UNKNOWN' : Math.round(v).toString(); }
  percent(v: number | null | undefined) { return v == null ? '—' : `${Math.round(v)}%`; }
  onImgError() { this.imgFailed.set(true); }

  private async mutate(success: string, action: () => Promise<unknown>, reset?: () => void) {
    if (this.busy()) return;
    try { this.busy.set(true); this.actionError.set(''); this.actionSuccess.set(''); await action(); reset?.(); await this.load(); this.actionSuccess.set(success); }
    catch (e) { this.actionError.set(this.message(e, 'Change could not be saved.')); }
    finally { this.busy.set(false); }
  }

  private message(error: unknown, fallback: string) { return error instanceof Error ? error.message : fallback; }
}
