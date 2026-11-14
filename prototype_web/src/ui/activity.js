// Обёртка для специализированных активных режимов (рыбалка и будущие).
// Активность — объект { id, title, intro, mount(container, params, finish) -> destroy }.
// finish(result) возвращает результат в основной режим; result = { outcome, loot?, summary? }.

import { h } from './dom.js';

export class ActivityScreen {
  constructor(game, activity, params, onEnd) {
    this.game = game;
    this.activity = activity;
    this.params = params || {};
    this.onEnd = onEnd;
  }

  mount(root) {
    const stage = h('div', { class: 'act-stage' });
    this.el = h('div', { class: 'activity-screen' },
      h('header', { class: 'act-head' },
        h('div', {}, h('div', { class: 'modal-kicker' }, 'Активность'), h('h2', {}, this.activity.title)),
        h('div', { class: 'act-intro muted' }, this.activity.intro || '')),
      stage);
    root.append(this.el);
    this.destroyActivity = this.activity.mount(stage, this.params, (result) => this.finish(result));
  }

  finish(result) {
    if (this.done) return;
    this.done = true;
    this.onEnd(result);
  }

  destroy() { this.destroyActivity?.(); }
}
