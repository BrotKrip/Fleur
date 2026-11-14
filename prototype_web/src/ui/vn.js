// Режим визуальной новеллы. Проигрывает сцену из src/content/scenes, применяет её эффекты
// к состоянию игры и по завершении возвращает список изменений в основной режим.

import { h, clear } from './dom.js';
import { CONTENT } from '../content/index.js';
import * as R from '../engine/rules.js';

export class VNScreen {
  constructor(game, scene, ctx, onEnd) {
    this.game = game;
    this.scene = scene;
    this.ctx = { ...ctx };
    this.onEnd = onEnd;
    this.api = { changes: [] };
    this.i = 0;
    this.labels = {};
    scene.nodes.forEach((n, idx) => { if (n.label) this.labels[n.label] = idx; });
    this.shown = new Map(); // id -> позиция
    this.history = [];
    this.typing = null;
    this.waiting = null; // 'click' | 'choice'
    this.speaker = null;
    this.keyHandler = (e) => {
      if (this.game.modals.stack.length) return;
      if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); this.advanceClick(); }
      if (this.waiting === 'choice' && /^[1-9]$/.test(e.key)) this.choiceButtons?.[Number(e.key) - 1]?.click();
    };
  }

  mount(root) {
    this.bg = h('div', { class: 'vn-bg' });
    this.bgLabel = h('div', { class: 'vn-bg-label' });
    this.chars = h('div', { class: 'vn-chars' });
    this.nameEl = h('div', { class: 'vn-name' });
    this.textEl = h('div', { class: 'vn-text' });
    this.box = h('div', { class: 'vn-box', onClick: () => this.advanceClick() }, this.nameEl, this.textEl, h('div', { class: 'vn-cont' }, '▸'));
    this.choices = h('div', { class: 'vn-choices' });
    const controls = h('div', { class: 'vn-controls' },
      h('button', { class: 'btn small ghost', onClick: (e) => { e.stopPropagation(); this.showHistory(); } }, 'История'),
      h('button', { class: 'btn small ghost', onClick: (e) => { e.stopPropagation(); this.game.modals.settings(); } }, 'Настройки'));
    this.el = h('div', { class: 'vn-screen' }, this.bg, this.bgLabel, this.chars, this.choices, this.box, controls,
      h('div', { class: 'vn-scene-title' }, this.scene.title || ''));
    root.append(this.el);
    window.addEventListener('keydown', this.keyHandler);
    this.run();
  }

  destroy() {
    window.removeEventListener('keydown', this.keyHandler);
    clearInterval(this.typing);
  }

  // Выполняет узлы до первого, который ждёт игрока
  run() {
    const s = this.game.state;
    const nodes = this.scene.nodes;
    let guard = 0;
    while (this.i < nodes.length) {
      if (guard++ > 1000) { console.error('VN: зацикливание'); break; }
      const n = nodes[this.i];
      if (n.label !== undefined) { this.i++; continue; }
      if (n.bg) { this.setBg(n.bg); this.i++; continue; }
      if (n.show) { this.shown.set(n.show, n.at || 'center'); this.renderChars(); this.i++; continue; }
      if (n.hide) { this.shown.delete(n.hide); this.renderChars(); this.i++; continue; }
      if (n.do) { R.apply(n.do, s, this.ctx, this.api); this.i++; continue; }
      if (n.if !== undefined) {
        if (R.test(n.if, s, this.ctx)) { this.i = this.labels[n.goto]; } else this.i++;
        continue;
      }
      if (n.goto) { this.i = this.labels[n.goto]; continue; }
      if (n.end) { this.finish(); return; }
      if (n.n !== undefined) { this.say(null, R.txt(n.n, s, this.ctx)); return; }
      if (n.s) { this.say(n.s, R.txt(n.t, s, this.ctx)); return; }
      if (n.choice) { this.showChoice(n.choice); return; }
      console.warn('VN: неизвестный узел', n);
      this.i++;
    }
    this.finish();
  }

  setBg(id) {
    const b = CONTENT.backgrounds[id];
    this.bg.style.background = b?.css || '#111';
    this.bgLabel.textContent = b?.label || '';
  }

  speakerInfo(id) {
    if (!id) return null;
    const def = R.getDef(id) || CONTENT.speakers[id];
    return { name: R.txt(def?.title, this.game.state) || id, color: def?.color || '#ddd' };
  }

  renderChars() {
    clear(this.chars);
    for (const [id, pos] of this.shown) {
      const sp = this.speakerInfo(id);
      this.chars.append(h('div', {
        class: `vn-char pos-${pos}${this.speaker && this.speaker !== id ? ' dim' : ''}${this.speaker === id ? ' talking' : ''}`,
        style: { '--accent': sp.color },
      }, h('div', { class: 'vn-char-initial' }, sp.name[0]), h('div', { class: 'vn-char-name' }, sp.name)));
    }
  }

  say(who, text) {
    this.speaker = who;
    this.renderChars();
    const sp = this.speakerInfo(who);
    this.nameEl.textContent = sp ? sp.name : '';
    this.nameEl.style.display = sp ? '' : 'none';
    this.nameEl.style.color = sp?.color || '';
    this.box.classList.toggle('narration', !who);
    this.history.push({ who: sp?.name || null, text });
    this.waiting = 'click';
    this.typeText(text);
  }

  typeText(text) {
    clearInterval(this.typing);
    const speed = this.game.settings.textSpeed;
    this.fullText = text;
    if (!speed) { this.textEl.textContent = text; this.typing = null; this.box.classList.add('done'); return; }
    this.box.classList.remove('done');
    let shown = 0;
    this.textEl.textContent = '';
    const step = Math.max(1, Math.round(speed / 30));
    this.typing = setInterval(() => {
      shown = Math.min(text.length, shown + step);
      this.textEl.textContent = text.slice(0, shown);
      if (shown >= text.length) { clearInterval(this.typing); this.typing = null; this.box.classList.add('done'); }
    }, 1000 / 30);
  }

  advanceClick() {
    if (this.waiting !== 'click') return;
    if (this.typing) {
      clearInterval(this.typing); this.typing = null;
      this.textEl.textContent = this.fullText; this.box.classList.add('done');
      return;
    }
    this.waiting = null;
    this.i++;
    this.run();
  }

  showChoice(options) {
    const s = this.game.state;
    this.waiting = 'choice';
    clear(this.choices);
    const avail = options.filter((o) => R.test(o.when, s, this.ctx));
    this.choiceButtons = avail.map((o, idx) => h('button', {
      class: 'vn-choice',
      onClick: (e) => {
        e.stopPropagation();
        clear(this.choices);
        this.choiceButtons = null;
        this.waiting = null;
        this.history.push({ who: '→', text: R.txt(o.t, s, this.ctx) });
        R.apply(o.effects, s, this.ctx, this.api);
        if (o.goto) this.i = this.labels[o.goto]; else this.i++;
        this.run();
      },
    }, h('span', { class: 'vn-choice-n' }, idx + 1), R.txt(o.t, s, this.ctx)));
    this.choices.append(...this.choiceButtons);
  }

  showHistory() {
    const m = this.game.modals;
    let close;
    close = m.open([
      h('h2', {}, 'История сцены'),
      h('div', { class: 'vn-history' }, this.history.map((e) =>
        h('div', { class: 'vn-h-entry' + (e.who ? '' : ' narr') }, e.who ? h('b', {}, e.who + ': ') : null, e.text))),
      h('div', { class: 'modal-actions' }, h('button', { class: 'btn primary', onClick: () => close() }, 'Закрыть')),
    ], { cls: 'history' });
  }

  finish() {
    if (this.finished) return;
    this.finished = true;
    this.onEnd(this.api.changes);
  }
}
