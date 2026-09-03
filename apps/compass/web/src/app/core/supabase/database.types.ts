export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  land: {
    Tables: {
      candidate_economics: {
        Row: {
          annual_revenue_base: number | null
          annual_revenue_conservative: number | null
          annual_revenue_upside: number | null
          assumptions: string | null
          candidate_id: string
          first_unit_fitout_capex: number | null
          immediate_infrastructure_safety_capex: number | null
          key_downside: string | null
          likely_purchase_price: number | null
          minimum_usable_state_capex: number | null
          phase1_capital_excluding_purchase: number | null
          total_phase1_capital: number | null
          transaction_legal_costs: number | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          annual_revenue_base?: number | null
          annual_revenue_conservative?: number | null
          annual_revenue_upside?: number | null
          assumptions?: string | null
          candidate_id: string
          first_unit_fitout_capex?: number | null
          immediate_infrastructure_safety_capex?: number | null
          key_downside?: string | null
          likely_purchase_price?: number | null
          minimum_usable_state_capex?: number | null
          phase1_capital_excluding_purchase?: number | null
          total_phase1_capital?: number | null
          transaction_legal_costs?: number | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          annual_revenue_base?: number | null
          annual_revenue_conservative?: number | null
          annual_revenue_upside?: number | null
          assumptions?: string | null
          candidate_id?: string
          first_unit_fitout_capex?: number | null
          immediate_infrastructure_safety_capex?: number | null
          key_downside?: string | null
          likely_purchase_price?: number | null
          minimum_usable_state_capex?: number | null
          phase1_capital_excluding_purchase?: number | null
          total_phase1_capital?: number | null
          transaction_legal_costs?: number | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "candidate_economics_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: true
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "candidate_economics_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: true
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "candidate_economics_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: true
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
        ]
      }
      candidate_gates: {
        Row: {
          candidate_id: string
          category: string
          gate_code: string
          gate_label: string
          id: string
          is_critical: boolean
          notes: string | null
          source_definition_id: string | null
          state: Database["public"]["Enums"]["gate_state"]
          updated_at: string
          updated_by: string | null
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          candidate_id: string
          category: string
          gate_code: string
          gate_label: string
          id?: string
          is_critical?: boolean
          notes?: string | null
          source_definition_id?: string | null
          state?: Database["public"]["Enums"]["gate_state"]
          updated_at?: string
          updated_by?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          candidate_id?: string
          category?: string
          gate_code?: string
          gate_label?: string
          id?: string
          is_critical?: boolean
          notes?: string | null
          source_definition_id?: string | null
          state?: Database["public"]["Enums"]["gate_state"]
          updated_at?: string
          updated_by?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "candidate_gates_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "candidate_gates_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "candidate_gates_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "candidate_gates_source_definition_id_fkey"
            columns: ["source_definition_id"]
            isOneToOne: false
            referencedRelation: "world_gate_definitions"
            referencedColumns: ["id"]
          },
        ]
      }
      candidate_media: {
        Row: {
          candidate_id: string
          caption: string | null
          created_at: string
          external_url: string | null
          id: string
          media_type: string
          sort_order: number
          source_id: string | null
          storage_path: string | null
        }
        Insert: {
          candidate_id: string
          caption?: string | null
          created_at?: string
          external_url?: string | null
          id?: string
          media_type?: string
          sort_order?: number
          source_id?: string | null
          storage_path?: string | null
        }
        Update: {
          candidate_id?: string
          caption?: string | null
          created_at?: string
          external_url?: string | null
          id?: string
          media_type?: string
          sort_order?: number
          source_id?: string | null
          storage_path?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "candidate_media_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "candidate_media_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "candidate_media_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "candidate_media_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "candidate_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      candidate_price_history: {
        Row: {
          candidate_id: string
          currency: string
          id: number
          note: string | null
          observed_at: string
          price: number
          source_id: string | null
        }
        Insert: {
          candidate_id: string
          currency?: string
          id?: never
          note?: string | null
          observed_at?: string
          price: number
          source_id?: string | null
        }
        Update: {
          candidate_id?: string
          currency?: string
          id?: never
          note?: string | null
          observed_at?: string
          price?: number
          source_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "candidate_price_history_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "candidate_price_history_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "candidate_price_history_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "candidate_price_history_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "candidate_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      candidate_sources: {
        Row: {
          candidate_id: string
          created_at: string
          first_seen_at: string
          id: string
          last_seen_at: string | null
          listing_status: Database["public"]["Enums"]["listing_status"]
          signal_id: string | null
          source_listing_id: string | null
          source_name: string
          source_snapshot: Json
          source_url: string | null
        }
        Insert: {
          candidate_id: string
          created_at?: string
          first_seen_at?: string
          id?: string
          last_seen_at?: string | null
          listing_status?: Database["public"]["Enums"]["listing_status"]
          signal_id?: string | null
          source_listing_id?: string | null
          source_name: string
          source_snapshot?: Json
          source_url?: string | null
        }
        Update: {
          candidate_id?: string
          created_at?: string
          first_seen_at?: string
          id?: string
          last_seen_at?: string | null
          listing_status?: Database["public"]["Enums"]["listing_status"]
          signal_id?: string | null
          source_listing_id?: string | null
          source_name?: string
          source_snapshot?: Json
          source_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "candidate_sources_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "candidate_sources_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "candidate_sources_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "candidate_sources_signal_id_fkey"
            columns: ["signal_id"]
            isOneToOne: false
            referencedRelation: "signals"
            referencedColumns: ["id"]
          },
        ]
      }
      candidates: {
        Row: {
          access_summary: string | null
          address_text: string | null
          area_m2: number | null
          asking_price: number | null
          asset_kind: Database["public"]["Enums"]["asset_kind"]
          country_code: string | null
          created_at: string
          created_by: string | null
          currency: string
          date_discovered: string
          description: string | null
          id: string
          infrastructure_summary: string | null
          internal_name: string | null
          last_seen_at: string | null
          latitude: number | null
          listing_status: Database["public"]["Enums"]["listing_status"]
          longitude: number | null
          max_price: number | null
          municipality: string | null
          next_action: string | null
          orientation: string | null
          ownership_type: string | null
          parcel_number: string | null
          price_per_m2: number | null
          property_type: string | null
          region: string | null
          settlement: string | null
          status: Database["public"]["Enums"]["candidate_status"]
          target_offer: number | null
          terrain: string | null
          title: string
          updated_at: string
          world_id: string
        }
        Insert: {
          access_summary?: string | null
          address_text?: string | null
          area_m2?: number | null
          asking_price?: number | null
          asset_kind: Database["public"]["Enums"]["asset_kind"]
          country_code?: string | null
          created_at?: string
          created_by?: string | null
          currency?: string
          date_discovered?: string
          description?: string | null
          id?: string
          infrastructure_summary?: string | null
          internal_name?: string | null
          last_seen_at?: string | null
          latitude?: number | null
          listing_status?: Database["public"]["Enums"]["listing_status"]
          longitude?: number | null
          max_price?: number | null
          municipality?: string | null
          next_action?: string | null
          orientation?: string | null
          ownership_type?: string | null
          parcel_number?: string | null
          price_per_m2?: number | null
          property_type?: string | null
          region?: string | null
          settlement?: string | null
          status?: Database["public"]["Enums"]["candidate_status"]
          target_offer?: number | null
          terrain?: string | null
          title: string
          updated_at?: string
          world_id: string
        }
        Update: {
          access_summary?: string | null
          address_text?: string | null
          area_m2?: number | null
          asking_price?: number | null
          asset_kind?: Database["public"]["Enums"]["asset_kind"]
          country_code?: string | null
          created_at?: string
          created_by?: string | null
          currency?: string
          date_discovered?: string
          description?: string | null
          id?: string
          infrastructure_summary?: string | null
          internal_name?: string | null
          last_seen_at?: string | null
          latitude?: number | null
          listing_status?: Database["public"]["Enums"]["listing_status"]
          longitude?: number | null
          max_price?: number | null
          municipality?: string | null
          next_action?: string | null
          orientation?: string | null
          ownership_type?: string | null
          parcel_number?: string | null
          price_per_m2?: number | null
          property_type?: string | null
          region?: string | null
          settlement?: string | null
          status?: Database["public"]["Enums"]["candidate_status"]
          target_offer?: number | null
          terrain?: string | null
          title?: string
          updated_at?: string
          world_id?: string
        }
        Relationships: []
      }
      dd_items: {
        Row: {
          candidate_id: string
          category: string
          created_at: string
          created_by: string | null
          description: string | null
          due_date: string | null
          gate_id: string | null
          id: string
          next_step: string | null
          notes: string | null
          owner_id: string | null
          severity: Database["public"]["Enums"]["dd_severity"]
          status: Database["public"]["Enums"]["dd_status"]
          title: string
          updated_at: string
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          candidate_id: string
          category: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          due_date?: string | null
          gate_id?: string | null
          id?: string
          next_step?: string | null
          notes?: string | null
          owner_id?: string | null
          severity?: Database["public"]["Enums"]["dd_severity"]
          status?: Database["public"]["Enums"]["dd_status"]
          title: string
          updated_at?: string
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          candidate_id?: string
          category?: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          due_date?: string | null
          gate_id?: string | null
          id?: string
          next_step?: string | null
          notes?: string | null
          owner_id?: string | null
          severity?: Database["public"]["Enums"]["dd_severity"]
          status?: Database["public"]["Enums"]["dd_status"]
          title?: string
          updated_at?: string
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "dd_items_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dd_items_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "dd_items_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dd_items_gate_id_fkey"
            columns: ["gate_id"]
            isOneToOne: false
            referencedRelation: "candidate_gates"
            referencedColumns: ["id"]
          },
        ]
      }
      decisions: {
        Row: {
          candidate_id: string
          decided_at: string
          decided_by: string | null
          decision: Database["public"]["Enums"]["decision_type"]
          id: string
          max_price: number | null
          previous_status:
            | Database["public"]["Enums"]["candidate_status"]
            | null
          reason: string
          resulting_status:
            | Database["public"]["Enums"]["candidate_status"]
            | null
          target_offer: number | null
        }
        Insert: {
          candidate_id: string
          decided_at?: string
          decided_by?: string | null
          decision: Database["public"]["Enums"]["decision_type"]
          id?: string
          max_price?: number | null
          previous_status?:
            | Database["public"]["Enums"]["candidate_status"]
            | null
          reason: string
          resulting_status?:
            | Database["public"]["Enums"]["candidate_status"]
            | null
          target_offer?: number | null
        }
        Update: {
          candidate_id?: string
          decided_at?: string
          decided_by?: string | null
          decision?: Database["public"]["Enums"]["decision_type"]
          id?: string
          max_price?: number | null
          previous_status?:
            | Database["public"]["Enums"]["candidate_status"]
            | null
          reason?: string
          resulting_status?:
            | Database["public"]["Enums"]["candidate_status"]
            | null
          target_offer?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "decisions_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "decisions_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "decisions_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
        ]
      }
      documents: {
        Row: {
          candidate_id: string
          captured_at: string | null
          created_at: string
          document_type: string | null
          id: string
          mime_type: string | null
          original_filename: string
          size_bytes: number | null
          source_name: string | null
          source_url: string | null
          storage_bucket: string
          storage_path: string
          title: string | null
          uploaded_by: string | null
        }
        Insert: {
          candidate_id: string
          captured_at?: string | null
          created_at?: string
          document_type?: string | null
          id?: string
          mime_type?: string | null
          original_filename: string
          size_bytes?: number | null
          source_name?: string | null
          source_url?: string | null
          storage_bucket?: string
          storage_path: string
          title?: string | null
          uploaded_by?: string | null
        }
        Update: {
          candidate_id?: string
          captured_at?: string | null
          created_at?: string
          document_type?: string | null
          id?: string
          mime_type?: string | null
          original_filename?: string
          size_bytes?: number | null
          source_name?: string | null
          source_url?: string | null
          storage_bucket?: string
          storage_path?: string
          title?: string | null
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "documents_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "documents_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "documents_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
        ]
      }
      evaluation_dimension_weights: {
        Row: {
          dimension: Database["public"]["Enums"]["score_dimension"]
          evaluation_id: string
          weight: number
        }
        Insert: {
          dimension: Database["public"]["Enums"]["score_dimension"]
          evaluation_id: string
          weight: number
        }
        Update: {
          dimension?: Database["public"]["Enums"]["score_dimension"]
          evaluation_id?: string
          weight?: number
        }
        Relationships: [
          {
            foreignKeyName: "evaluation_dimension_weights_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "evaluations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluation_dimension_weights_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_latest_evaluation"
            referencedColumns: ["evaluation_id"]
          },
          {
            foreignKeyName: "evaluation_dimension_weights_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["evaluation_id"]
          },
          {
            foreignKeyName: "evaluation_dimension_weights_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "v_evaluation_scores"
            referencedColumns: ["evaluation_id"]
          },
        ]
      }
      evaluation_items: {
        Row: {
          confidence_percent: number
          criterion_code: string
          criterion_label: string
          dimension: Database["public"]["Enums"]["score_dimension"]
          evaluation_id: string
          evidence_state: Database["public"]["Enums"]["evidence_state"]
          id: string
          is_required: boolean
          item_weight: number
          rationale: string | null
          score: number | null
          source_criterion_id: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          confidence_percent?: number
          criterion_code: string
          criterion_label: string
          dimension: Database["public"]["Enums"]["score_dimension"]
          evaluation_id: string
          evidence_state?: Database["public"]["Enums"]["evidence_state"]
          id?: string
          is_required?: boolean
          item_weight: number
          rationale?: string | null
          score?: number | null
          source_criterion_id?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          confidence_percent?: number
          criterion_code?: string
          criterion_label?: string
          dimension?: Database["public"]["Enums"]["score_dimension"]
          evaluation_id?: string
          evidence_state?: Database["public"]["Enums"]["evidence_state"]
          id?: string
          is_required?: boolean
          item_weight?: number
          rationale?: string | null
          score?: number | null
          source_criterion_id?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "evaluation_items_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "evaluations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluation_items_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_latest_evaluation"
            referencedColumns: ["evaluation_id"]
          },
          {
            foreignKeyName: "evaluation_items_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["evaluation_id"]
          },
          {
            foreignKeyName: "evaluation_items_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "v_evaluation_scores"
            referencedColumns: ["evaluation_id"]
          },
          {
            foreignKeyName: "evaluation_items_source_criterion_id_fkey"
            columns: ["source_criterion_id"]
            isOneToOne: false
            referencedRelation: "world_score_criteria"
            referencedColumns: ["id"]
          },
        ]
      }
      evaluations: {
        Row: {
          candidate_id: string
          concerns: string[]
          created_at: string
          created_by: string | null
          evaluator_note: string | null
          finalized_at: string | null
          id: string
          status: Database["public"]["Enums"]["evaluation_status"]
          version_no: number
          why_compass_likes_it: string[]
          world_id: string
        }
        Insert: {
          candidate_id: string
          concerns?: string[]
          created_at?: string
          created_by?: string | null
          evaluator_note?: string | null
          finalized_at?: string | null
          id?: string
          status?: Database["public"]["Enums"]["evaluation_status"]
          version_no: number
          why_compass_likes_it?: string[]
          world_id: string
        }
        Update: {
          candidate_id?: string
          concerns?: string[]
          created_at?: string
          created_by?: string | null
          evaluator_note?: string | null
          finalized_at?: string | null
          id?: string
          status?: Database["public"]["Enums"]["evaluation_status"]
          version_no?: number
          why_compass_likes_it?: string[]
          world_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "evaluations_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluations_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "evaluations_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
        ]
      }
      evidence_items: {
        Row: {
          candidate_id: string
          created_at: string
          created_by: string | null
          dd_item_id: string | null
          document_id: string | null
          evaluation_item_id: string | null
          evidence_type: Database["public"]["Enums"]["evidence_type"]
          gate_id: string | null
          id: string
          observed_at: string | null
          source_url: string | null
          statement: string | null
          title: string
          verification_state: Database["public"]["Enums"]["verification_state"]
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          candidate_id: string
          created_at?: string
          created_by?: string | null
          dd_item_id?: string | null
          document_id?: string | null
          evaluation_item_id?: string | null
          evidence_type: Database["public"]["Enums"]["evidence_type"]
          gate_id?: string | null
          id?: string
          observed_at?: string | null
          source_url?: string | null
          statement?: string | null
          title: string
          verification_state?: Database["public"]["Enums"]["verification_state"]
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          candidate_id?: string
          created_at?: string
          created_by?: string | null
          dd_item_id?: string | null
          document_id?: string | null
          evaluation_item_id?: string | null
          evidence_type?: Database["public"]["Enums"]["evidence_type"]
          gate_id?: string | null
          id?: string
          observed_at?: string | null
          source_url?: string | null
          statement?: string | null
          title?: string
          verification_state?: Database["public"]["Enums"]["verification_state"]
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "evidence_items_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evidence_items_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "evidence_items_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evidence_items_dd_item_id_fkey"
            columns: ["dd_item_id"]
            isOneToOne: false
            referencedRelation: "dd_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evidence_items_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evidence_items_evaluation_item_id_fkey"
            columns: ["evaluation_item_id"]
            isOneToOne: false
            referencedRelation: "evaluation_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evidence_items_gate_id_fkey"
            columns: ["gate_id"]
            isOneToOne: false
            referencedRelation: "candidate_gates"
            referencedColumns: ["id"]
          },
        ]
      }
      notes: {
        Row: {
          body: string
          candidate_id: string
          created_at: string
          created_by: string | null
          id: string
          note_type: string
          updated_at: string
        }
        Insert: {
          body: string
          candidate_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          note_type?: string
          updated_at?: string
        }
        Update: {
          body?: string
          candidate_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          note_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notes_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notes_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "notes_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
        ]
      }
      score_dimensions: {
        Row: {
          code: Database["public"]["Enums"]["score_dimension"]
          label: string
          sort_order: number
        }
        Insert: {
          code: Database["public"]["Enums"]["score_dimension"]
          label: string
          sort_order: number
        }
        Update: {
          code?: Database["public"]["Enums"]["score_dimension"]
          label?: string
          sort_order?: number
        }
        Relationships: []
      }
      signals: {
        Row: {
          created_at: string
          created_by: string | null
          discovered_at: string
          extracted_payload: Json
          extraction_status: string | null
          id: string
          last_seen_at: string | null
          promoted_candidate_id: string | null
          raw_area_m2: number | null
          raw_currency: string | null
          raw_description: string | null
          raw_location: string | null
          raw_payload: Json
          raw_price: number | null
          raw_title: string | null
          source_listing_id: string | null
          source_name: string | null
          source_url: string | null
          status: Database["public"]["Enums"]["signal_status"]
          updated_at: string
          world_id: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          discovered_at?: string
          extracted_payload?: Json
          extraction_status?: string | null
          id?: string
          last_seen_at?: string | null
          promoted_candidate_id?: string | null
          raw_area_m2?: number | null
          raw_currency?: string | null
          raw_description?: string | null
          raw_location?: string | null
          raw_payload?: Json
          raw_price?: number | null
          raw_title?: string | null
          source_listing_id?: string | null
          source_name?: string | null
          source_url?: string | null
          status?: Database["public"]["Enums"]["signal_status"]
          updated_at?: string
          world_id?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          discovered_at?: string
          extracted_payload?: Json
          extraction_status?: string | null
          id?: string
          last_seen_at?: string | null
          promoted_candidate_id?: string | null
          raw_area_m2?: number | null
          raw_currency?: string | null
          raw_description?: string | null
          raw_location?: string | null
          raw_payload?: Json
          raw_price?: number | null
          raw_title?: string | null
          source_listing_id?: string | null
          source_name?: string | null
          source_url?: string | null
          status?: Database["public"]["Enums"]["signal_status"]
          updated_at?: string
          world_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "signals_promoted_candidate_id_fkey"
            columns: ["promoted_candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "signals_promoted_candidate_id_fkey"
            columns: ["promoted_candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "signals_promoted_candidate_id_fkey"
            columns: ["promoted_candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
        ]
      }
      visits: {
        Row: {
          access_note: string | null
          candidate_id: string
          created_at: string
          id: string
          infrastructure_note: string | null
          latitude: number | null
          longitude: number | null
          nature_note: string | null
          overall_note: string | null
          visited_at: string
          visited_by: string | null
          weather_note: string | null
        }
        Insert: {
          access_note?: string | null
          candidate_id: string
          created_at?: string
          id?: string
          infrastructure_note?: string | null
          latitude?: number | null
          longitude?: number | null
          nature_note?: string | null
          overall_note?: string | null
          visited_at: string
          visited_by?: string | null
          weather_note?: string | null
        }
        Update: {
          access_note?: string | null
          candidate_id?: string
          created_at?: string
          id?: string
          infrastructure_note?: string | null
          latitude?: number | null
          longitude?: number | null
          nature_note?: string | null
          overall_note?: string | null
          visited_at?: string
          visited_by?: string | null
          weather_note?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "visits_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "visits_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "visits_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
        ]
      }
      world_dimension_weights: {
        Row: {
          dimension: Database["public"]["Enums"]["score_dimension"]
          weight: number
          world_id: string
        }
        Insert: {
          dimension: Database["public"]["Enums"]["score_dimension"]
          weight: number
          world_id: string
        }
        Update: {
          dimension?: Database["public"]["Enums"]["score_dimension"]
          weight?: number
          world_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "world_dimension_weights_dimension_fkey"
            columns: ["dimension"]
            isOneToOne: false
            referencedRelation: "score_dimensions"
            referencedColumns: ["code"]
          },
        ]
      }
      world_gate_definitions: {
        Row: {
          category: string
          code: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          is_critical: boolean
          label: string
          sort_order: number
          world_id: string
        }
        Insert: {
          category: string
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          is_critical?: boolean
          label: string
          sort_order?: number
          world_id: string
        }
        Update: {
          category?: string
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          is_critical?: boolean
          label?: string
          sort_order?: number
          world_id?: string
        }
        Relationships: []
      }
      world_score_criteria: {
        Row: {
          code: string
          created_at: string
          description: string | null
          dimension: Database["public"]["Enums"]["score_dimension"]
          id: string
          is_active: boolean
          is_required: boolean
          item_weight: number
          label: string
          sort_order: number
          world_id: string
        }
        Insert: {
          code: string
          created_at?: string
          description?: string | null
          dimension: Database["public"]["Enums"]["score_dimension"]
          id?: string
          is_active?: boolean
          is_required?: boolean
          item_weight?: number
          label: string
          sort_order?: number
          world_id: string
        }
        Update: {
          code?: string
          created_at?: string
          description?: string | null
          dimension?: Database["public"]["Enums"]["score_dimension"]
          id?: string
          is_active?: boolean
          is_required?: boolean
          item_weight?: number
          label?: string
          sort_order?: number
          world_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "world_score_criteria_dimension_fkey"
            columns: ["dimension"]
            isOneToOne: false
            referencedRelation: "score_dimensions"
            referencedColumns: ["code"]
          },
        ]
      }
    }
    Views: {
      v_candidate_gate_summary: {
        Row: {
          candidate_id: string | null
          critical_failed_count: number | null
          critical_unknown_count: number | null
          failed_count: number | null
          gate_count: number | null
          passed_count: number | null
          unknown_count: number | null
        }
        Relationships: []
      }
      v_candidate_latest_evaluation: {
        Row: {
          candidate_id: string | null
          compass_score: number | null
          confidence_percent: number | null
          created_at: string | null
          evaluation_id: string | null
          finalized_at: string | null
          rn: number | null
          status: Database["public"]["Enums"]["evaluation_status"] | null
          version_no: number | null
        }
        Relationships: [
          {
            foreignKeyName: "evaluations_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluations_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "evaluations_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
        ]
      }
      v_candidate_radar: {
        Row: {
          area_m2: number | null
          asking_price: number | null
          asset_kind: Database["public"]["Enums"]["asset_kind"] | null
          compass_score: number | null
          confidence_percent: number | null
          country_code: string | null
          critical_failed_count: number | null
          critical_unknown_count: number | null
          currency: string | null
          evaluation_id: string | null
          failed_count: number | null
          id: string | null
          last_seen_at: string | null
          listing_status: Database["public"]["Enums"]["listing_status"] | null
          municipality: string | null
          price_per_m2: number | null
          recommendation: string | null
          region: string | null
          settlement: string | null
          status: Database["public"]["Enums"]["candidate_status"] | null
          title: string | null
          total_phase1_capital: number | null
          unknown_count: number | null
          world_code: string | null
          world_id: string | null
          world_name: string | null
        }
        Relationships: []
      }
      v_evaluation_dimension_scores: {
        Row: {
          criterion_count: number | null
          dimension: Database["public"]["Enums"]["score_dimension"] | null
          dimension_confidence: number | null
          dimension_score: number | null
          evaluation_id: string | null
          scored_count: number | null
          unknown_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "evaluation_items_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "evaluations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluation_items_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_latest_evaluation"
            referencedColumns: ["evaluation_id"]
          },
          {
            foreignKeyName: "evaluation_items_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["evaluation_id"]
          },
          {
            foreignKeyName: "evaluation_items_evaluation_id_fkey"
            columns: ["evaluation_id"]
            isOneToOne: false
            referencedRelation: "v_evaluation_scores"
            referencedColumns: ["evaluation_id"]
          },
        ]
      }
      v_evaluation_scores: {
        Row: {
          candidate_id: string | null
          compass_score: number | null
          confidence_percent: number | null
          created_at: string | null
          evaluation_id: string | null
          finalized_at: string | null
          status: Database["public"]["Enums"]["evaluation_status"] | null
          version_no: number | null
        }
        Relationships: [
          {
            foreignKeyName: "evaluations_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluations_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_gate_summary"
            referencedColumns: ["candidate_id"]
          },
          {
            foreignKeyName: "evaluations_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "v_candidate_radar"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      can_admin: { Args: never; Returns: boolean }
      can_analyze: { Args: never; Returns: boolean }
      can_contribute_evidence: { Args: never; Returns: boolean }
      can_read: { Args: never; Returns: boolean }
      has_app_role: {
        Args: { allowed: Database["public"]["Enums"]["app_role"][] }
        Returns: boolean
      }
      initialize_candidate_gates: {
        Args: { p_candidate_id: string }
        Returns: number
      }
      promote_signal_to_candidate: {
        Args: { p_signal_id: string; p_title?: string; p_world_id: string }
        Returns: string
      }
      start_evaluation: { Args: { p_candidate_id: string }; Returns: string }
    }
    Enums: {
      app_role: "OWNER" | "ADMIN" | "ANALYST" | "ADVISOR" | "VIEWER"
      asset_kind: "LAND" | "BUILDING" | "FLOATING" | "MOBILE" | "OTHER"
      candidate_status:
        | "NEW"
        | "REVIEWED"
        | "SHORTLIST"
        | "DD"
        | "NEGOTIATION"
        | "ACQUIRED"
        | "REJECTED"
        | "ARCHIVED"
        | "SOLD"
      dd_severity: "INFO" | "IMPORTANT" | "GATE"
      dd_status:
        | "OPEN"
        | "IN_PROGRESS"
        | "VERIFIED"
        | "FAILED"
        | "NOT_APPLICABLE"
      decision_type:
        | "REVIEW"
        | "SHORTLIST"
        | "START_DD"
        | "NEGOTIATE"
        | "REJECT"
        | "ARCHIVE"
        | "ACQUIRE"
        | "REOPEN"
      evaluation_status: "DRAFT" | "FINAL"
      evidence_state: "UNKNOWN" | "CLAIMED" | "OBSERVED" | "VERIFIED"
      evidence_type:
        | "SELLER_STATEMENT"
        | "LISTING"
        | "DOCUMENT"
        | "REGISTRY"
        | "PROFESSIONAL_OPINION"
        | "PHOTO"
        | "SITE_VISIT"
        | "MAP"
        | "EXTERNAL_URL"
        | "OTHER"
      gate_state: "UNKNOWN" | "PASS" | "FAIL" | "NOT_APPLICABLE"
      listing_status: "ACTIVE" | "REMOVED" | "SOLD" | "EXPIRED" | "UNKNOWN"
      score_dimension:
        | "PLACE"
        | "FEASIBILITY"
        | "ECONOMICS"
        | "OUTLAND"
        | "NETWORK"
      signal_status: "NEW" | "REVIEWED" | "PROMOTED" | "DISMISSED" | "STALE"
      verification_state:
        | "UNVERIFIED"
        | "PARTIALLY_VERIFIED"
        | "VERIFIED"
        | "DISPUTED"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  shared: {
    Tables: {
      activities: {
        Row: {
          action: string
          actor_id: string | null
          candidate_id: string | null
          created_at: string
          entity_id: string | null
          entity_type: string
          id: number
          new_data: Json | null
          old_data: Json | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          candidate_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          id?: never
          new_data?: Json | null
          old_data?: Json | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          candidate_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          id?: never
          new_data?: Json | null
          old_data?: Json | null
        }
        Relationships: []
      }
      assets: {
        Row: {
          acquired_at: string | null
          acquisition_price: number | null
          asset_kind: Database["public"]["Enums"]["asset_kind"]
          created_at: string
          created_by: string | null
          currency: string
          id: string
          name: string
          source_candidate_id: string | null
          status: string
          updated_at: string
          world_id: string
        }
        Insert: {
          acquired_at?: string | null
          acquisition_price?: number | null
          asset_kind: Database["public"]["Enums"]["asset_kind"]
          created_at?: string
          created_by?: string | null
          currency?: string
          id?: string
          name: string
          source_candidate_id?: string | null
          status?: string
          updated_at?: string
          world_id: string
        }
        Update: {
          acquired_at?: string | null
          acquisition_price?: number | null
          asset_kind?: Database["public"]["Enums"]["asset_kind"]
          created_at?: string
          created_by?: string | null
          currency?: string
          id?: string
          name?: string
          source_candidate_id?: string | null
          status?: string
          updated_at?: string
          world_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "assets_world_id_fkey"
            columns: ["world_id"]
            isOneToOne: false
            referencedRelation: "worlds"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          display_name: string | null
          email: string | null
          id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_name?: string | null
          email?: string | null
          id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_name?: string | null
          email?: string | null
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          created_at: string
          created_by: string | null
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      worlds: {
        Row: {
          archetype: string | null
          asset_kind: Database["public"]["Enums"]["asset_kind"]
          code: string
          created_at: string
          environment: string | null
          id: string
          inner_movement: string | null
          is_active: boolean
          name: string
          radar_enabled: boolean
          reunderwrite_above_eur: number | null
          search_notes: string | null
          target_area_max_m2: number | null
          target_area_min_m2: number | null
          target_capital_max_eur: number | null
          target_capital_min_eur: number | null
          target_geography: string | null
          target_profile: Json
          updated_at: string
        }
        Insert: {
          archetype?: string | null
          asset_kind: Database["public"]["Enums"]["asset_kind"]
          code: string
          created_at?: string
          environment?: string | null
          id?: string
          inner_movement?: string | null
          is_active?: boolean
          name: string
          radar_enabled?: boolean
          reunderwrite_above_eur?: number | null
          search_notes?: string | null
          target_area_max_m2?: number | null
          target_area_min_m2?: number | null
          target_capital_max_eur?: number | null
          target_capital_min_eur?: number | null
          target_geography?: string | null
          target_profile?: Json
          updated_at?: string
        }
        Update: {
          archetype?: string | null
          asset_kind?: Database["public"]["Enums"]["asset_kind"]
          code?: string
          created_at?: string
          environment?: string | null
          id?: string
          inner_movement?: string | null
          is_active?: boolean
          name?: string
          radar_enabled?: boolean
          reunderwrite_above_eur?: number | null
          search_notes?: string | null
          target_area_max_m2?: number | null
          target_area_min_m2?: number | null
          target_capital_max_eur?: number | null
          target_capital_min_eur?: number | null
          target_geography?: string | null
          target_profile?: Json
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  land: {
    Enums: {},
  },
  public: {
    Enums: {
      app_role: ["OWNER", "ADMIN", "ANALYST", "ADVISOR", "VIEWER"],
      asset_kind: ["LAND", "BUILDING", "FLOATING", "MOBILE", "OTHER"],
      candidate_status: [
        "NEW",
        "REVIEWED",
        "SHORTLIST",
        "DD",
        "NEGOTIATION",
        "ACQUIRED",
        "REJECTED",
        "ARCHIVED",
        "SOLD",
      ],
      dd_severity: ["INFO", "IMPORTANT", "GATE"],
      dd_status: [
        "OPEN",
        "IN_PROGRESS",
        "VERIFIED",
        "FAILED",
        "NOT_APPLICABLE",
      ],
      decision_type: [
        "REVIEW",
        "SHORTLIST",
        "START_DD",
        "NEGOTIATE",
        "REJECT",
        "ARCHIVE",
        "ACQUIRE",
        "REOPEN",
      ],
      evaluation_status: ["DRAFT", "FINAL"],
      evidence_state: ["UNKNOWN", "CLAIMED", "OBSERVED", "VERIFIED"],
      evidence_type: [
        "SELLER_STATEMENT",
        "LISTING",
        "DOCUMENT",
        "REGISTRY",
        "PROFESSIONAL_OPINION",
        "PHOTO",
        "SITE_VISIT",
        "MAP",
        "EXTERNAL_URL",
        "OTHER",
      ],
      gate_state: ["UNKNOWN", "PASS", "FAIL", "NOT_APPLICABLE"],
      listing_status: ["ACTIVE", "REMOVED", "SOLD", "EXPIRED", "UNKNOWN"],
      score_dimension: [
        "PLACE",
        "FEASIBILITY",
        "ECONOMICS",
        "OUTLAND",
        "NETWORK",
      ],
      signal_status: ["NEW", "REVIEWED", "PROMOTED", "DISMISSED", "STALE"],
      verification_state: [
        "UNVERIFIED",
        "PARTIALLY_VERIFIED",
        "VERIFIED",
        "DISPUTED",
      ],
    },
  },
  shared: {
    Enums: {},
  },
} as const