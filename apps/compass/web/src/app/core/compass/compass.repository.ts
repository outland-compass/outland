import { Injectable } from '@angular/core';

import { Tables, TablesInsert, TablesUpdate } from '../supabase/database.types';
import { SupabaseService } from '../supabase/supabase.service';

export type RadarRow = Tables<{ schema: 'land' }, 'v_candidate_radar'>;
export type World = Tables<{ schema: 'shared' }, 'worlds'>;
export type Candidate = Tables<{ schema: 'land' }, 'candidates'>;
export type Gate = Tables<{ schema: 'land' }, 'candidate_gates'>;
export type EvaluationItem = Tables<{ schema: 'land' }, 'evaluation_items'>;
export type Signal = Tables<{ schema: 'land' }, 'signals'>;

export interface ImportedListing {
  source_name: string | null;
  source_url: string;
  source_listing_id: string | null;
  title: string | null;
  location: string | null;
  price: number | null;
  currency: string | null;
  area_m2: number | null;
  description: string | null;
  image_url: string | null;
}

// candidate_sources.source_snapshot already carries the signal's raw_payload;
// reusing it avoids a new media table/column for a single image URL.
export function extractSourceImage(snapshot: unknown): string | null {
  if (!snapshot || typeof snapshot !== 'object') return null;
  const payload = (snapshot as Record<string, unknown>)['raw_payload'];
  if (!payload || typeof payload !== 'object') return null;
  const value = (payload as Record<string, unknown>)['image_url'];
  return typeof value === 'string' && value.trim() ? value : null;
}

@Injectable({ providedIn: 'root' })
export class CompassRepository {
  constructor(private readonly supabase: SupabaseService) {}

  private get db() { return this.supabase.client; }
  private get land() { return this.supabase.client.schema('land'); }
  private get shared() { return this.supabase.client.schema('shared'); }

  async radar(): Promise<RadarRow[]> { return this.data(this.land.from('v_candidate_radar').select('*')); }
  async worlds(): Promise<World[]> { return this.data(this.shared.from('worlds').select('*').order('name')); }
  async signals(): Promise<Signal[]> { return this.data(this.land.from('signals').select('*').order('discovered_at', { ascending: false }).limit(30)); }
  async candidate(id: string): Promise<Candidate> { return this.one(this.land.from('candidates').select('*').eq('id', id).single()); }
  async radarCandidate(id: string): Promise<RadarRow> { return this.one(this.land.from('v_candidate_radar').select('*').eq('id', id).single()); }
  async gates(candidateId: string): Promise<Gate[]> { return this.data(this.land.from('candidate_gates').select('*').eq('candidate_id', candidateId).order('category')); }
  async sources(candidateId: string) { return this.data(this.land.from('candidate_sources').select('*').eq('candidate_id', candidateId)); }
  async sourceUrls(candidateIds: string[]): Promise<{ candidate_id: string; source_url: string | null; image_url: string | null }[]> { if (!candidateIds.length) return []; const rows = await this.data(this.land.from('candidate_sources').select('candidate_id,source_url,source_snapshot').in('candidate_id', candidateIds)); return rows.map((row) => ({ candidate_id: row.candidate_id, source_url: row.source_url, image_url: extractSourceImage(row.source_snapshot) })); }
  async prices(candidateId: string) { return this.data(this.land.from('candidate_price_history').select('*').eq('candidate_id', candidateId).order('observed_at', { ascending: false })); }
  async economics(candidateId: string) { return this.oneOrNull(this.land.from('candidate_economics').select('*').eq('candidate_id', candidateId).maybeSingle()); }
  async notes(candidateId: string) { return this.data(this.land.from('notes').select('*').eq('candidate_id', candidateId).order('created_at', { ascending: false })); }
  async evidence(candidateId: string) { return this.data(this.land.from('evidence_items').select('*').eq('candidate_id', candidateId).order('created_at', { ascending: false })); }
  async ddItems() { return this.data(this.land.from('dd_items').select('*').order('due_date')); }

  async latestEvaluation(candidateId: string) { return this.oneOrNull(this.land.from('v_candidate_latest_evaluation').select('*').eq('candidate_id', candidateId).maybeSingle()); }
  async evaluation(id: string) { return this.one(this.land.from('evaluations').select('*').eq('id', id).single()); }
  async dimensions(evaluationId: string) { return this.data(this.land.from('v_evaluation_dimension_scores').select('*').eq('evaluation_id', evaluationId)); }
  async evaluationItems(evaluationId: string): Promise<EvaluationItem[]> { return this.data(this.land.from('evaluation_items').select('*').eq('evaluation_id', evaluationId).order('dimension')); }

  async createSignal(signal: TablesInsert<{ schema: 'land' }, 'signals'>): Promise<Signal> { return this.one(this.land.from('signals').insert(signal).select().single()); }
  async importListing(url: string): Promise<ImportedListing> { const { data, error } = await this.db.functions.invoke('import-listing', { body: { url } }); if (error) { const message = await this.functionErrorMessage(error); throw new Error(message); } if (data && typeof data === 'object' && 'error' in data) { throw new Error(String((data as { error: unknown }).error)); } return data as ImportedListing; }
  async signalByUrl(sourceUrl: string): Promise<Signal | null> { return this.oneOrNull(this.land.from('signals').select('*').eq('source_url', sourceUrl).limit(1).maybeSingle()); }
  async signalByListingId(sourceName: string, listingId: string): Promise<Signal | null> { return this.oneOrNull(this.land.from('signals').select('*').eq('source_name', sourceName).eq('source_listing_id', listingId).limit(1).maybeSingle()); }
  async promoteSignal(signalId: string, worldId: string, title?: string): Promise<string> { return this.one(this.db.rpc('promote_signal_to_candidate', { p_signal_id: signalId, p_world_id: worldId, p_title: title })); }
  async startEvaluation(candidateId: string): Promise<string> { return this.one(this.db.rpc('start_evaluation', { p_candidate_id: candidateId })); }
  async updateEvaluationItem(id: string, update: TablesUpdate<{ schema: 'land' }, 'evaluation_items'>): Promise<void> { await this.mutate(this.land.from('evaluation_items').update(update).eq('id', id)); }
  async updateGate(id: string, update: TablesUpdate<{ schema: 'land' }, 'candidate_gates'>): Promise<void> { await this.mutate(this.land.from('candidate_gates').update(update).eq('id', id)); }
  async addNote(note: TablesInsert<{ schema: 'land' }, 'notes'>): Promise<void> { await this.mutate(this.land.from('notes').insert(note)); }

  private async data<T>(request: PromiseLike<{ data: T[] | null; error: { message: string } | null }>): Promise<T[]> { const { data, error } = await request; if (error) throw new Error(error.message); return data ?? []; }
  private async one<T>(request: PromiseLike<{ data: T | null; error: { message: string } | null }>): Promise<T> { const { data, error } = await request; if (error || data === null) throw new Error(error?.message ?? 'No data returned.'); return data; }
  private async oneOrNull<T>(request: PromiseLike<{ data: T | null; error: { message: string } | null }>): Promise<T | null> { const { data, error } = await request; if (error) throw new Error(error.message); return data; }
  private async mutate(request: PromiseLike<{ error: { message: string } | null }>): Promise<void> { const { error } = await request; if (error) throw new Error(error.message); }
  private async functionErrorMessage(error: unknown): Promise<string> { const context = (error as { context?: unknown })?.context; if (context instanceof Response) { try { const body = await context.clone().json(); if (body && typeof body === 'object' && 'error' in body) return String((body as { error: unknown }).error); } catch { /* fall through to the generic message */ } } return error instanceof Error ? error.message : 'Listing could not be imported.'; }
}
