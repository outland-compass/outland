import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CompassRepository, World } from '../../core/compass/compass.repository';
import { Json } from '../../core/supabase/database.types';

type JsonObject = { [key: string]: Json | undefined };
type HuntForm = {
  developmentTrack: string;
  priceMin: number | null;
  pricePreferredMax: number | null;
  priceHardMax: number | null;
  priceExceptionalMax: number | null;
  areaMin: number | null;
  areaMax: number | null;
  walkToSea: number | null;
  legalPath: string;
  phaseSequence: string;
};

@Component({
  imports: [FormsModule],
  template: `<section class="page">
    <header class="page-header"><div><p class="eyebrow">OUTLAND CORE</p><h1>WORLDS</h1><p>Live investment thesis and Land Hunt parameters. Saturday Deep Hunt reads these values from Supabase.</p></div></header>
    @if(error()){<div class="state error">{{error()}}</div>}
    @if(success()){<div class="state success">{{success()}}</div>}
    <div class="world-grid">
      @for(world of worlds();track world.id){
        <article [class.disabled]="!world.radar_enabled">
          <div><span class="world">{{world.code}}</span>@if(!world.radar_enabled){<span class="disabled-pill">RADAR DISABLED</span>}</div>
          <h2>{{world.name}}</h2>
          <p>{{world.environment}} · {{world.archetype}} · {{world.inner_movement}}</p>
          <dl><dt>Geography</dt><dd>{{world.target_geography || '—'}}</dd><dt>Total development capital</dt><dd>{{money(world.target_capital_min_eur)}} – {{money(world.target_capital_max_eur)}}</dd><dt>Legacy target area</dt><dd>{{world.target_area_min_m2 || '—'}} – {{world.target_area_max_m2 || '—'}} m²</dd><dt>Re-underwrite</dt><dd>{{money(world.reunderwrite_above_eur)}}</dd></dl>
          @if(isFloating(world)){
            <div class="hunt-summary">
              <h3>LOCATION / ASSET SEARCH</h3>
              <p><strong>FLOATING</strong></p>
              <p>RAFTER is governed by legal berth/location, safe floating asset and operating-envelope criteria — Land Hunt does not apply.</p>
            </div>
          } @else if(editingId()===world.id){
            <div class="hunt-editor">
              <h3>LAND HUNT</h3>
              <label>Development track<select [(ngModel)]="form().developmentTrack"><option value="PERMANENT">PERMANENT</option><option value="WILDLAND_POD">WILDLAND_POD</option><option value="LOW_IMPACT_WORK_RETREAT">LOW_IMPACT_WORK_RETREAT</option></select></label>
              <div class="field-grid">
                <label>Land price min €<input type="number" [(ngModel)]="form().priceMin" /></label>
                <label>Preferred max €<input type="number" [(ngModel)]="form().pricePreferredMax" /></label>
                <label>Hard max €<input type="number" [(ngModel)]="form().priceHardMax" /></label>
                <label>Exceptional max €<input type="number" [(ngModel)]="form().priceExceptionalMax" /></label>
                <label>Area min m²<input type="number" [(ngModel)]="form().areaMin" /></label>
                <label>Area max m²<input type="number" [(ngModel)]="form().areaMax" /></label>
                <label>Ideal walk to sea m<input type="number" [(ngModel)]="form().walkToSea" /></label>
              </div>
              <label>Legal path<textarea rows="3" [(ngModel)]="form().legalPath"></textarea></label>
              <label>Phase sequence<textarea rows="2" [(ngModel)]="form().phaseSequence"></textarea></label>
              <div class="actions"><button class="primary" (click)="save(world)" [disabled]="saving()">{{saving()?'Saving…':'Save Land Hunt'}}</button><button (click)="cancel()" [disabled]="saving()">Cancel</button></div>
            </div>
          } @else {
            <div class="hunt-summary">
              <h3>LAND HUNT</h3>
              <p><strong>{{hunt(world)['development_track'] || profile(world)['development_track'] || 'Not configured'}}</strong></p>
              <p>Land: {{priceRange(world)}} · Area: {{areaRange(world)}}</p>
              @if(hunt(world)['legal_path']){<p class="legal">{{hunt(world)['legal_path']}}</p>}
              <button (click)="edit(world)">Edit Land Hunt</button>
            </div>
          }
        </article>
      }
    </div>
  </section>`,
  styleUrl: './worlds.page.scss'
})
export default class WorldsPage {
  readonly repo=inject(CompassRepository);
  readonly worlds=signal<World[]>([]);
  readonly error=signal('');
  readonly success=signal('');
  readonly editingId=signal<string|null>(null);
  readonly saving=signal(false);
  readonly form=signal<HuntForm>(this.emptyForm());

  constructor(){void this.load()}
  async load(){try{this.worlds.set(await this.repo.worlds())}catch(e){this.error.set(e instanceof Error?e.message:'World profiles could not load.')}}
  money(value:number|null){return value==null?'—':new Intl.NumberFormat('en-IE',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(value)}

  profile(world:World):JsonObject{return this.object(world.target_profile)}
  hunt(world:World):JsonObject{return this.object(this.profile(world)['land_hunt'])}
  isFloating(world:World){return this.text(this.profile(world)['development_track'])==='FLOATING'}
  edit(world:World){const profile=this.profile(world);const hunt=this.hunt(world);const price=this.object(hunt['target_land_price_eur']);const area=this.object(hunt['preferred_area_m2']);this.error.set('');this.success.set('');this.form.set({developmentTrack:this.text(profile['development_track']),priceMin:this.num(price['min']),pricePreferredMax:this.num(price['preferred_max']),priceHardMax:this.num(price['hard_max']),priceExceptionalMax:this.num(price['exceptional_max']),areaMin:this.num(area['min']),areaMax:this.num(area['max']),walkToSea:this.num(hunt['ideal_walk_to_sea_m']),legalPath:this.text(hunt['legal_path']),phaseSequence:this.text(hunt['phase_sequence'])});this.editingId.set(world.id)}
  cancel(){this.editingId.set(null)}

  async save(world:World){
    this.saving.set(true);this.error.set('');this.success.set('');
    try{
      const current=this.profile(world);const oldHunt=this.hunt(world);const oldPrice=this.object(oldHunt['target_land_price_eur']);const oldArea=this.object(oldHunt['preferred_area_m2']);const f=this.form();
      const price:JsonObject={...oldPrice};this.assignNumber(price,'min',f.priceMin);this.assignNumber(price,'preferred_max',f.pricePreferredMax);this.assignNumber(price,'hard_max',f.priceHardMax);this.assignNumber(price,'exceptional_max',f.priceExceptionalMax);
      const area:JsonObject={...oldArea};this.assignNumber(area,'min',f.areaMin);this.assignNumber(area,'max',f.areaMax);
      const landHunt:JsonObject={...oldHunt,target_land_price_eur:price,preferred_area_m2:area};this.assignText(landHunt,'legal_path',f.legalPath);this.assignText(landHunt,'phase_sequence',f.phaseSequence);this.assignNumber(landHunt,'ideal_walk_to_sea_m',f.walkToSea);
      const targetProfile:JsonObject={...current,land_hunt:landHunt};this.assignText(targetProfile,'development_track',f.developmentTrack);
      await this.repo.updateWorld(world.id,{target_profile:targetProfile as Json});
      await this.load();this.editingId.set(null);this.success.set(`${world.name} Land Hunt updated. Future Deep Hunt runs will use the live values.`);
    }catch(e){this.error.set(e instanceof Error?e.message:'Land Hunt could not be saved.')}finally{this.saving.set(false)}
  }

  priceRange(world:World){const p=this.object(this.hunt(world)['target_land_price_eur']);const min=this.num(p['min']);const preferred=this.num(p['preferred_max']);const hard=this.num(p['hard_max']);const exceptional=this.num(p['exceptional_max']);if(min==null&&preferred==null&&hard==null&&exceptional==null)return '—';const ceiling=preferred??hard??exceptional;let result=`${this.money(min)} – ${this.money(ceiling)}`;if(hard!=null&&hard!==ceiling)result+=` (hard ${this.money(hard)})`;if(exceptional!=null&&exceptional!==ceiling)result+=` (exceptional ${this.money(exceptional)})`;return result}
  areaRange(world:World){const a=this.object(this.hunt(world)['preferred_area_m2']);const min=this.num(a['min']);const max=this.num(a['max']);if(min==null&&max==null)return '—';return `${min??'—'} – ${max??'—'} m²`}
  private emptyForm():HuntForm{return{developmentTrack:'PERMANENT',priceMin:null,pricePreferredMax:null,priceHardMax:null,priceExceptionalMax:null,areaMin:null,areaMax:null,walkToSea:null,legalPath:'',phaseSequence:''}}
  private object(value:Json|undefined):JsonObject{return value&&typeof value==='object'&&!Array.isArray(value)?value as JsonObject:{}}
  private text(value:Json|undefined){return typeof value==='string'?value:''}
  private num(value:Json|undefined){return typeof value==='number'?value:null}
  private assignText(target:JsonObject,key:string,value:string){if(value.trim())target[key]=value.trim();else delete target[key]}
  private assignNumber(target:JsonObject,key:string,value:number|null){if(value!=null&&Number.isFinite(value))target[key]=value;else delete target[key]}
}
