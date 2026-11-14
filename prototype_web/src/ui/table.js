// Основной режим: стол с картами, места, панель подробностей и журнал.

import { h, clear, paragraphs } from './dom.js';
import { CONTENT } from '../content/index.js';
import * as R from '../engine/rules.js';
import { cardEl, relChip, TYPES, lifetimeLabel } from './common.js';

const ZONES = [
  { title: 'Дела и сюжетные линии', types: ['affair', 'storyline'] },
  { title: 'События и приглашения', types: ['invitation', 'event'], hideEmpty: false, empty: 'Пока ничего не происходит.' },
  { title: 'Люди', types: ['person'] },
  { title: 'Сведения, слухи, улики', types: ['clue', 'info', 'rumor'], empty: 'Ничего интересного он пока не слышал.' },
  { title: 'Предметы', types: ['item'] },
  { title: 'Состояния', types: ['state', 'world'], empty: 'Ничего примечательного.' },
];

export class TableScreen {
  constructor(game) {
    this.game = game;
    this.selected = { id: 'loc_apartment' };
  }

  mount(root) {
    this.el = h('div', { class: 'table-screen' });
    root.append(this.el);
    this.render();
  }

  destroy() {}

  select(id) {
    this.selected = { id };
    this.render();
  }

  render() {
    const s = this.game.state;
    if (!s || !this.el) return;
    if (!s.cards[this.selected.id]) this.selected = { id: 'loc_apartment' };
    clear(this.el);
    this.el.append(this.topbar(s), h('div', { class: 'table-main' }, this.locations(s), this.board(s), this.side(s)));
  }

  topbar(s) {
    const g = this.game;
    return h('header', { class: 'topbar' },
      h('div', { class: 'tb-title' }, h('span', { class: 'tb-name' }, 'Шевалье де ла Флёр'), h('span', { class: 'muted' }, ' · Кур-де-Фонтейн')),
      h('div', { class: 'tb-time' },
        h('span', { class: 'tb-day' }, `День ${s.day}`),
        h('div', { class: 'phase-track' }, R.PHASES.map((p, i) =>
          h('span', { class: `phase${i === s.phase ? ' now' : ''}${i < s.phase ? ' past' : ''}` }, p)))),
      h('div', { class: 'tb-btns' },
        h('button', { class: 'btn small', title: 'Пропустить часть дня', onClick: () => g.wait() }, 'Переждать ⟶'),
        h('button', { class: 'btn small ghost', onClick: () => g.modals.journal() }, 'Журнал'),
        h('button', { class: 'btn small ghost', onClick: () => g.modals.saveLoad('save') }, 'Сохранить'),
        h('button', { class: 'btn small ghost', onClick: () => g.modals.saveLoad('load') }, 'Загрузить'),
        h('button', { class: 'btn small ghost', onClick: () => g.modals.settings() }, 'Настройки'),
        h('button', { class: 'btn small ghost', onClick: () => g.modals.pause() }, 'Меню')));
  }

  locations(s) {
    const locs = Object.keys(s.cards).filter((id) => R.getDef(id).type === 'location');
    return h('aside', { class: 'locations' },
      h('div', { class: 'zone-title' }, 'Места'),
      locs.map((id) => {
        const def = R.getDef(id);
        const bg = CONTENT.backgrounds[def.bg];
        const people = R.peopleAt(s, id);
        const acts = R.actionsFor(s, id).filter((a) => R.canDo(a, s, R.actionCtx(a, id, {})).ok || a.slots).length;
        return h('div', {
          class: `loc${this.selected.id === id ? ' selected' : ''}${s.cards[id].fresh ? ' fresh' : ''}`,
          style: { '--locbg': bg?.css || '#333' },
          onClick: () => this.select(id),
        },
        h('div', { class: 'loc-title' }, R.txt(def.title, s)),
        h('div', { class: 'loc-sub' }, def.subtitle),
        h('div', { class: 'loc-foot' },
          people.length ? h('span', { class: 'loc-people' }, '♟ ' + people.map((p) => R.cardTitle(p, s)).join(', ')) : null,
          h('span', { class: 'loc-acts' }, acts ? `${acts} ${acts === 1 ? 'дело' : 'дела'}` : '')));
      }));
  }

  board(s) {
    const ids = Object.keys(s.cards);
    return h('section', { class: 'board' },
      this.game.settings.showHints ? h('div', { class: 'hint' }, 'Выберите место слева, чтобы увидеть, чем там можно заняться, или карту на столе — чтобы рассмотреть её. Каждое действие занимает время; мир живёт и без вашего участия.') : null,
      ZONES.map((z) => {
        const list = ids.filter((id) => z.types.includes(R.getDef(id).type))
          .sort((a, b) => z.types.indexOf(R.getDef(a).type) - z.types.indexOf(R.getDef(b).type));
        if (!list.length && !z.empty) return null;
        return h('div', { class: 'zone' },
          h('div', { class: 'zone-title' }, z.title),
          h('div', { class: 'zone-cards' },
            list.length ? list.map((id) => cardEl(id, s, { selected: this.selected.id === id, onClick: (cid) => this.select(cid) }))
              : h('div', { class: 'muted zone-empty' }, z.empty)));
      }));
  }

  side(s) {
    const id = this.selected.id;
    const def = R.getDef(id);
    const inst = s.cards[id];
    const isLoc = def.type === 'location';
    const bg = isLoc ? CONTENT.backgrounds[def.bg] : null;
    const actions = R.actionsFor(s, id);

    const detail = h('div', { class: 'detail' },
      isLoc ? h('div', { class: 'detail-banner', style: { background: bg?.css } }, h('span', {}, R.txt(def.title, s))) : null,
      h('div', { class: 'modal-kicker' }, (TYPES[def.type]?.icon || '') + ' ' + (def.type === 'person' ? 'Человек' : (R.txt(def.subtitle, s) || TYPES[def.type]?.name))),
      !isLoc ? h('h2', { style: def.color ? { color: def.color } : null }, R.txt(def.title, s)) : h('div', { class: 'muted' }, def.subtitle),
      def.type === 'person' ? h('div', { class: 'muted' }, def.subtitle + (def.vision ? ` · Глаз Бога: ${def.vision}` : ' · Глаза Бога нет')) : null,
      h('div', { class: 'prose' }, paragraphs(R.txt(def.text, s))),
      def.type === 'person' ? this.personInfo(id, s) : null,
      inst?.lifetime != null ? h('div', { class: 'card-life' + (inst.lifetime <= 1 ? ' urgent' : '') }, '⏳ Исчезнет через: ' + lifetimeLabel(inst.lifetime)) : null,
      isLoc ? this.presentPeople(id, s) : null,
      actions.length ? h('div', { class: 'actions' },
        h('div', { class: 'zone-title' }, isLoc ? 'Чем заняться' : 'Действия'),
        actions.map((a) => this.actionButton(a, id, s))) : null);

    const journal = h('div', { class: 'journal' },
      h('div', { class: 'zone-title' }, 'Последнее'),
      [...s.log].slice(-12).reverse().map((e) =>
        h('div', { class: 'j-entry j-' + e.kind }, h('span', { class: 'j-time' }, `Д${e.day} · ${R.PHASES[e.phase]}`), ' ', e.text)));

    return h('aside', { class: 'side' }, detail, journal);
  }

  personInfo(id, s) {
    const where = R.whereIs(s, id);
    return h('div', { class: 'person-info' },
      h('div', {}, h('span', { class: 'muted' }, 'Сейчас: '), where ? R.cardTitle(where, s) : 'неизвестно где'),
      h('div', { class: 'rels' }, h('span', { class: 'muted' }, 'Отношения: '), (s.rel[id] || []).length ? (s.rel[id] || []).map(relChip) : h('span', { class: 'muted' }, '—')));
  }

  presentPeople(loc, s) {
    const people = R.peopleAt(s, loc);
    if (!people.length) return null;
    return h('div', { class: 'present' }, h('div', { class: 'zone-title' }, 'Здесь сейчас'),
      h('div', { class: 'zone-cards' }, people.map((p) => cardEl(p, s, { compact: true, onClick: (cid) => this.select(cid) }))));
  }

  actionButton(a, where, s) {
    const ctx = R.actionCtx(a, where, {});
    const check = R.canDo(a, s, ctx);
    // Если действие не выполнимо лишь из-за пустого слота — его можно открыть и заполнить
    const onlySlots = !check.ok && (a.slots || []).some((sl) => sl.required) && check.reason.startsWith('Нужно');
    const enabled = check.ok || onlySlots;
    const cost = R.costOf(a, s);
    return h('button', {
      class: 'action-btn' + (enabled ? '' : ' disabled'),
      onClick: () => (enabled ? this.game.modals.action(a, where) : this.game.modals.toast(check.reason)),
    },
    h('span', { class: 'a-title' }, a.title),
    h('span', { class: 'a-meta' }, enabled ? (cost === 0 ? '·' : '◷'.repeat(Math.min(cost, 4))) : check.reason));
  }
}
