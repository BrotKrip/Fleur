// Модальные окна: уведомления о событиях, итоги действий, окно действия со слотами,
// сохранение/загрузка, настройки, пауза, всплывающие подсказки.

import { h, clear, paragraphs } from './dom.js';
import { CONTENT } from '../content/index.js';
import * as R from '../engine/rules.js';
import { listSaves, deleteSave } from '../engine/state.js';
import { cardEl, changesList, TYPES } from './common.js';

export class Modals {
  constructor(root, game) {
    this.root = root;
    this.game = game;
    this.stack = [];
  }

  open(content, { onClose, cls = '', dismissable = true } = {}) {
    const box = h('div', { class: 'modal ' + cls }, content);
    const overlay = h('div', { class: 'overlay' }, box);
    const entry = { overlay, onClose, dismissable, closed: false };
    entry.close = () => {
      if (entry.closed) return;
      entry.closed = true;
      overlay.remove();
      this.stack = this.stack.filter((e) => e !== entry);
      onClose?.();
    };
    overlay.addEventListener('mousedown', (e) => { if (e.target === overlay && dismissable) entry.close(); });
    this.root.append(overlay);
    this.stack.push(entry);
    requestAnimationFrame(() => overlay.classList.add('shown'));
    return entry.close;
  }

  closeTop() {
    const top = this.stack[this.stack.length - 1];
    if (!top || !top.dismissable) return !!top;
    top.close();
    return true;
  }

  closeAll() {
    for (const e of [...this.stack]) { e.onClose = null; e.closed = true; e.overlay.remove(); }
    this.stack = [];
  }

  toast(text) {
    const el = h('div', { class: 'toast' }, text);
    document.body.append(el);
    requestAnimationFrame(() => el.classList.add('shown'));
    setTimeout(() => { el.classList.remove('shown'); setTimeout(() => el.remove(), 400); }, 2200);
  }

  // ---------- Уведомление о событии мира ----------
  notice(n, onClose) {
    let close;
    const btn = h('button', { class: 'btn primary', onClick: () => close() }, 'Продолжить');
    close = this.open([
      h('div', { class: 'modal-kicker' }, n.kind === 'intro' ? 'Начало' : 'Событие'),
      h('h2', {}, n.title || 'Событие'),
      h('div', { class: 'prose' }, paragraphs(n.text)),
      h('div', { class: 'modal-actions' }, btn),
    ], { onClose, cls: 'notice' });
    setTimeout(() => btn.focus(), 30);
  }

  // ---------- Итог действия ----------
  result({ title, text, changes }, onClose) {
    const s = this.game.state;
    const list = changesList(changes, s);
    if (!text && !list) { onClose?.(); return; }
    let close;
    const btn = h('button', { class: 'btn primary', onClick: () => close() }, 'Дальше');
    close = this.open([
      h('h2', {}, title),
      text ? h('div', { class: 'prose' }, paragraphs(text)) : null,
      list ? h('div', { class: 'changes-wrap' }, h('div', { class: 'modal-kicker' }, 'Изменения'), list) : null,
      h('div', { class: 'modal-actions' }, btn),
    ], { onClose, cls: 'result' });
    setTimeout(() => btn.focus(), 30);
  }

  // ---------- Окно действия со слотами ----------
  action(action, where) {
    const game = this.game;
    const s = game.state;
    const slots = {};
    const body = h('div', { class: 'action-body' });
    let close;

    const render = () => {
      clear(body);
      const ctx = R.actionCtx(action, where, slots);
      const check = R.canDo(action, s, ctx);
      const cost = R.costOf(action, s);
      body.append(
        h('div', { class: 'modal-kicker' }, R.isLocation(where) ? R.cardTitle(where, s) : 'Действие'),
        h('h2', {}, action.title),
        action.desc ? h('div', { class: 'prose' }, paragraphs(R.txt(action.desc, s, ctx))) : null,
        h('div', { class: 'slots-wrap' }, (action.slots || []).map((sl) => {
          const filled = slots[sl.id];
          const cands = R.slotCandidates(sl, s, ctx);
          return h('div', { class: 'slot-row' },
            h('div', { class: 'slot-label' }, sl.label + (sl.required ? '' : '')),
            h('div', { class: 'slot-cards' },
              cands.length === 0 ? h('div', { class: 'muted' }, 'Нет подходящих карт.') : null,
              cands.map((id) => cardEl(id, s, {
                compact: true, selected: filled === id,
                onClick: () => { slots[sl.id] = filled === id ? null : id; render(); },
              }))));
        })),
        h('div', { class: 'action-meta' },
          cost === 0 ? 'Почти не займёт времени.' : `Займёт: ${cost} ${cost === 1 ? 'часть' : (cost < 5 ? 'части' : 'частей')} дня.`,
          !check.ok ? h('div', { class: 'warn' }, check.reason) : null),
        h('div', { class: 'modal-actions' },
          h('button', { class: 'btn', onClick: () => close() }, 'Отмена'),
          h('button', { class: 'btn primary', disabled: !check.ok, onClick: () => { close(); game.doAction(action, where, { ...slots }); } }, 'Сделать')),
      );
    };
    render();
    close = this.open(body, { cls: 'action' });
  }

  // ---------- Сохранение и загрузка ----------
  saveLoad(mode) {
    const game = this.game;
    const body = h('div');
    let close;
    const render = () => {
      clear(body);
      body.append(
        h('h2', {}, mode === 'save' ? 'Сохранить игру' : 'Загрузить игру'),
        h('div', { class: 'slots' }, listSaves().map(({ slot, data }) => {
          if (mode === 'save' && slot === 'auto') return null;
          const label = slot === 'auto' ? 'Автосохранение' : `Ячейка ${slot}`;
          const info = data
            ? (data.incompatible ? 'Несовместимая версия' : `День ${data.day}, ${R.PHASES[data.phase].toLowerCase()} · ${new Date(data.savedAt).toLocaleString('ru-RU')}`)
            : 'Пусто';
          return h('div', { class: 'slot' },
            h('div', {}, h('div', { class: 'slot-name' }, label), h('div', { class: 'muted' }, info)),
            h('div', { class: 'slot-btns' },
              mode === 'save'
                ? h('button', { class: 'btn primary', onClick: () => { game.saveSlot(slot); render(); } }, data ? 'Перезаписать' : 'Сохранить')
                : h('button', { class: 'btn primary', disabled: !data || data.incompatible, onClick: () => { close(); game.loadSlot(slot); } }, 'Загрузить'),
              data && slot !== 'auto' ? h('button', { class: 'btn ghost', onClick: () => { deleteSave(slot); render(); } }, 'Удалить') : null));
        })),
        mode === 'save' && game.mode !== 'table' ? h('div', { class: 'warn' }, 'Сохранять можно только в основном режиме.') : null,
        h('div', { class: 'modal-actions' }, h('button', { class: 'btn', onClick: () => close() }, 'Закрыть')),
      );
    };
    render();
    close = this.open(body, { cls: 'saveload' });
  }

  // ---------- Настройки ----------
  settings() {
    const game = this.game;
    const st = game.settings;
    let close;
    const row = (label, control) => h('label', { class: 'set-row' }, h('span', {}, label), control);
    const speedOut = h('span', { class: 'muted' });
    const speedLabel = (v) => (Number(v) === 0 ? 'мгновенно' : `${v} зн./с`);
    speedOut.textContent = speedLabel(st.textSpeed);
    const body = [
      h('h2', {}, 'Настройки'),
      row('Скорость текста в сценах', h('div', { class: 'set-ctl' },
        h('input', { type: 'range', min: 0, max: 120, step: 5, value: st.textSpeed,
          onInput: (e) => { game.updateSettings({ textSpeed: Number(e.target.value) }); speedOut.textContent = speedLabel(e.target.value); } }),
        speedOut)),
      row('Размер шрифта', h('select', { onChange: (e) => game.updateSettings({ fontScale: Number(e.target.value) }) },
        [[0.9, 'Мелкий'], [1, 'Обычный'], [1.12, 'Крупный'], [1.25, 'Очень крупный']].map(([v, l]) =>
          h('option', { value: v, selected: Number(st.fontScale) === v }, l)))),
      row('Громкость (звука пока нет)', h('input', { type: 'range', min: 0, max: 1, step: 0.05, value: st.volume,
        onInput: (e) => game.updateSettings({ volume: Number(e.target.value) }) })),
      row('Автосохранение', h('input', { type: 'checkbox', checked: st.autosave, onChange: (e) => game.updateSettings({ autosave: e.target.checked }) })),
      row('Подсказки на столе', h('input', { type: 'checkbox', checked: st.showHints, onChange: (e) => { game.updateSettings({ showHints: e.target.checked }); game.screen?.render?.(); } })),
      row('Полноэкранный режим', h('button', { class: 'btn', onClick: () => {
        if (document.fullscreenElement) document.exitFullscreen(); else document.documentElement.requestFullscreen?.();
      } }, 'Переключить')),
      h('div', { class: 'modal-actions' }, h('button', { class: 'btn primary', onClick: () => close() }, 'Готово')),
    ];
    close = this.open(body, { cls: 'settings' });
  }

  // ---------- Пауза ----------
  pause() {
    const game = this.game;
    let close;
    const b = (label, fn, cls = '') => h('button', { class: 'btn wide ' + cls, onClick: () => { close(); fn(); } }, label);
    close = this.open([
      h('h2', {}, 'Пауза'),
      h('div', { class: 'menu-list' },
        b('Вернуться', () => {}, 'primary'),
        b('Сохранить', () => this.saveLoad('save')),
        b('Загрузить', () => this.saveLoad('load')),
        b('Настройки', () => this.settings()),
        b('Выйти в главное меню', () => this.confirm('Выйти в главное меню? Несохранённый прогресс останется только в автосохранении.', () => { game.autosave(); game.showMenu(); }))),
    ], { cls: 'pause' });
  }

  confirm(text, onYes) {
    let close;
    close = this.open([
      h('div', { class: 'prose' }, paragraphs(text)),
      h('div', { class: 'modal-actions' },
        h('button', { class: 'btn', onClick: () => close() }, 'Нет'),
        h('button', { class: 'btn primary', onClick: () => { close(); onYes(); } }, 'Да')),
    ], { cls: 'confirm' });
  }

  // ---------- Журнал (полный) ----------
  journal() {
    const s = this.game.state;
    let close;
    close = this.open([
      h('h2', {}, 'Журнал'),
      h('div', { class: 'journal full' }, [...s.log].reverse().map((e) =>
        h('div', { class: 'j-entry j-' + e.kind }, h('span', { class: 'j-time' }, `Д${e.day} · ${R.PHASES[e.phase]}`), ' ', e.text))),
      h('div', { class: 'modal-actions' }, h('button', { class: 'btn primary', onClick: () => close() }, 'Закрыть')),
    ], { cls: 'journal-modal' });
  }
}

export { TYPES, CONTENT };
