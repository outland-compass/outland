import { Injectable } from '@angular/core';

import { Tables, TablesInsert, TablesUpdate } from '../supabase/database.types';
import { SupabaseService } from '../supabase/supabase.service';

export type RadarRow = Tables<'v_candidate_radar'>;
export type World = Tables<'worlds'>;
export type Candidate = Tables<'candidates'>;
export type Gate = Tables<'candidate_gates'>;
export type EvaluationItem = Tables<'evaluation_items'>;
export type Signal = Tables<'signals'>;

@Injectable({ providedIn: 'root' })
export class CompassRepository {
  constructor(private readonly supabase: SupabaseService) {}

  private get db() { return this.supabase.client; }

  async radar(): Promise<RadarRow[]> { return this.data(this.db.from('v_candidate_radar').select('*')); }
  async worlds(): Promise<World[]> { return this.data(this.db.from('worlds').select('*').order('name')); }
  async signals(): Promise<Signal[]> { return this.data(this.db.from('signals').select('*').order('discovered_at', { ascending: false }).limit(30)); }
  async candidate(id: string): Promise<Candidate> { return this.one(this.db.from('candidates').select('*').eq('id', id).single()); }
  async radarCandidate(id: string): Promise<RadarRow> { return this.one(this.db.from('v_candidate_radar').select('*').eq('id', id).single()); }
  async gates(candidateId: string): Promise<Gate[]> { return this.data(this.db.from('candidate_gates').select('*').eq('candidate_id', candidateId).order('category')); }
  async sources(candidateId: string) { return this.data(this.db.from('candidate_sources').select('*').eq('candidate_id', candidateId)); }
  async prices(candidateId: string) { return this.data(this.db.from('candidate_price_history').select('*').eq('candidate_id', candidateId).order('observed_at', { ascending: false })); }
  async economics(candidateId: string) { return this.oneOrNull(this.db.from('candidate_economics').select('*').eq('candidate_id', candidateId).maybeSingle()); }
  async notes(candidateId: string) { return this.data(this.db.from('notes').select('*').eq('candidate_id', candidateId).order('created_at', { ascending: false })); }
  async evidence(candidateId: string) { return this.data(this.db.from('evidence_items').select('*').eq('candidate_id', candidateId).order('created_at', { ascending: false })); }
  async ddItems() { return this.data(this.db.from('dd_items').select('*').order('due_date')); }

  async latestEvaluation(candidateId: string) { return this.oneOrNull(this.db.from('v_candidate_latest_evaluation').select('*').eq('candidate_id', candidateId).maybeSingle()); }
  async evaluation(id: string) { return this.one(this.db.from('evaluations').select('*').eq('id', id).single()); }
  async dimensions(evaluationId: string) { return this.data(this.db.from('v_evaluation_dimension_scores').select('*').eq('evaluation_id', evaluationId)); }
  async evaluationItems(evaluationId: string): Promise<EvaluationItem[]> { return this.data(this.db.from('evaluation_items').select('*').eq('evaluation_id', evaluationId).order('dimension')); }

  async createSignal(signal: TablesInsert<'signals'>): Promise<Signal> { return this.one(this.db.from('signals').insert(signal).select().single()); }
  async promoteSignal(signalId: string, worldId: string, title?: string): Promise<string> { return this.one(this.db.rpc('promote_signal_to_candidate', { p_signal_id: signalId, p_world_id: worldId, p_title: title })); }
  async startEvaluation(candidateId: string): Promise<string> { return this.one(this.db.rpc('start_evaluation', { p_candidate_id: candidateId })); }
  async updateEvaluationItem(id: string, update: TablesUpdate<'evaluation_items'>): Promise<void> { await this.mutate(this.db.from('evaluation_items').update(update).eq('id', id)); }
  async updateGate(id: string, update: TablesUpdate<'candidate_gates'>): Promise<void> { await this.mutate(this.db.from('candidate_gates').update(update).eq('id', id)); }
  async addNote(note: TablesInsert<'notes'>): Promise<void> { await this.mutate(this.db.from('notes').insert(note)); }

  private async data<T>(request: PromiseLike<{ data: T[] | null; error: { message: string } | null }>): Promise<T[]> { const { data, error } = await request; if (error) throw new Error(error.message); return data ?? []; }
  private async one<T>(request: PromiseLike<{ data: T | null; error: { message: string } | null }>): Promise<T> { const { data, error } = await request; if (error || data === null) throw new Error(error?.message ?? 'No data returned.'); return data; }
  private async oneOrNull<T>(request: PromiseLike<{ data: T | null; error: { message: string } | null }>): Promise<T | null> { const { data, error } = await request; if (error) throw new Error(error.message); return data; }
  private async mutate(request: PromiseLike<{ error: { message: string } | null }>): Promise<void> { const { error } = await request; if (error) throw new Error(error.message); }
}
