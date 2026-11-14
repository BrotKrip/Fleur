// Оркестратор: держит состояние, переключает режимы (меню / стол / VN / активности),
// проводит «поток» после каждого действия: уведомления о событиях -> сцены и активности -> стол.

import { CONTENT } from './content/index.js';
import * as R from './engine/rules.js';
import { newState, writeSave, readSave, latestSave, loadSettings, saveSettings } from './engine/state.js';
import { clear } from './ui/dom.js';
import { Modals } from './ui/modals.js';
import { MainMenu } from './ui/menu.js';
import { TableScreen } from './ui/table.js';
import { VNScreen } from './ui/vn.js';
import { ActivityScreen } from './ui/activity.js';
import { ACTIVITIES } from './activities/index.js';

export class Game {
  constructor(root, modalRoot) {
    this.root = root;
    this.modals = new Modals(modalRoot, this);
    this.settings = loadSettings();
    this.applySettings();
    this.state = null;
    this.screen = null;
    this.mode = 'menu';
    window.addEventListener('keydown', (e) => this.onKey(e));
  }

  start() { this.showMenu(); }

  // ---------- Режимы ----------

  setScreen(screen, mode) {
    this.screen?.destroy?.();
    clear(this.root);
    this.mode = mode;
    this.screen = screen;
    screen.mount(this.root);
  }

  showMenu() {
    this.modals.closeAll();
    this.setScreen(new MainMenu(this), 'menu');
  }

  newGame() {
    this.state = newState();
    this.toTable();
  }

  continueGame() {
    const latest = latestSave();
    if (latest) this.loadSlot(latest.slot);
  }

  loadSlot(slot) {
    const data = readSave(slot);
    if (!data || data.incompatible) { this.modals.toast('Сохранение не подходит к этой версии игры.'); return; }
    this.state = data.state;
    R.markSeen(this.state);
    this.modals.closeAll();
    this.toTable();
    this.modals.toast('Загружено.');
  }

  saveSlot(slot) {
    if (this.mode !== 'table' || !this.state) return false;
    const ok = writeSave(slot, this.state);
    this.modals.toast(ok ? 'Сохранено.' : 'Не удалось сохранить.');
    return ok;
  }

  autosave() {
    if (this.settings.autosave && this.state && this.mode === 'table') writeSave('auto', this.state);
  }

  toTable({ flow = true } = {}) {
    this.setScreen(new TableScreen(this), 'table');
    if (flow) this.flow();
  }

  // Разбор очереди: сначала уведомления о событиях, потом сцены/активности, потом стол и автосейв.
  flow() {
    const s = this.state;
    if (this.mode !== 'table') return;
    this.screen.render();
    if (s.notices.length) {
      const n = s.notices.shift();
      this.modals.notice(n, () => this.flow());
      return;
    }
    if (s.queue.length) {
      const q = s.queue.shift();
      if (q.type === 'scene') return this.enterScene(q.id, q.ctx);
      if (q.type === 'activity') return this.enterActivity(q);
    }
    this.autosave();
  }

  enterScene(id, ctx = {}) {
    const scene = CONTENT.scenes[id];
    if (!scene) { console.error('Нет сцены', id); return this.flow(); }
    this.setScreen(new VNScreen(this, scene, ctx, (changes) => {
      this.toTable({ flow: false });
      this.modals.result({ title: 'После разговора', text: '', changes }, () => this.flow());
    }), 'vn');
  }

  enterActivity(q) {
    const act = ACTIVITIES[q.id];
    if (!act) { console.error('Нет активности', q.id); return this.flow(); }
    this.setScreen(new ActivityScreen(this, act, q.params, (result) => {
      const api = { changes: [] };
      const map = q.onResult && CONTENT.activityResults[q.onResult];
      const r = map ? map(result) : { text: '', effects: [] };
      R.apply(r.effects, this.state, {}, api);
      const text = [result.summary, r.text].filter(Boolean).join('\n\n');
      R.log(this.state, `${act.title}: ${r.text || result.summary || ''}`, 'action');
      this.toTable({ flow: false });
      this.modals.result({ title: act.title, text, changes: api.changes }, () => this.flow());
    }), 'activity');
  }

  // ---------- Действия на столе ----------

  doAction(action, where, slots) {
    const s = this.state;
    const ctx = R.actionCtx(action, where, slots);
    const check = R.canDo(action, s, ctx);
    if (!check.ok) { this.modals.toast(check.reason); return; }
    const api = { changes: [] };
    R.markSeen(s);
    const res = R.perform(action, s, ctx, api);
    this.screen.render();
    if (action.silent) return this.flow();
    this.modals.result({ title: res.title, text: res.text, changes: api.changes }, () => this.flow());
  }

  wait() {
    const s = this.state;
    const api = { changes: [] };
    R.markSeen(s);
    R.log(s, 'Флёр позволил времени идти своим чередом.', 'action');
    R.advance(s, 1, api);
    this.screen.render();
    if (api.changes.length) this.modals.result({ title: 'Время идёт', text: '', changes: api.changes }, () => this.flow());
    else this.flow();
  }

  // ---------- Настройки ----------

  applySettings() {
    document.documentElement.style.setProperty('--font-scale', this.settings.fontScale);
  }

  updateSettings(patch) {
    Object.assign(this.settings, patch);
    saveSettings(this.settings);
    this.applySettings();
  }

  onKey(e) {
    if (e.key === 'Escape') {
      if (this.modals.closeTop()) return;
      if (this.mode === 'table') this.modals.pause();
    }
  }
}
