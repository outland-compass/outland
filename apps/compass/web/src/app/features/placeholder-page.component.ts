import { Component, input } from '@angular/core';

@Component({
  selector: 'app-placeholder-page',
  template: `<main><h1>{{ title() }}</h1><p>COMPASS v0.1 foundation.</p></main>`
})
export class PlaceholderPageComponent {
  readonly title = input.required<string>();
}
