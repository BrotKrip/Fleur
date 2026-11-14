// Общие элементы интерфейса: типы карт, отрисовка карты, список изменений.

import { h } from './dom.js';
import * as R from '../engine/rules.js';

export const TYPES = {
  location: { name: 'Место', icon: '⌂' },
  person: { name: 'Человек', icon: '♟' },
  affair: { name: 'Дело', icon: '✒' },
  storyline: { name: 'Сюжетная линия', icon: '❦' },
  event: { name: 'Событие', icon: '✦' },
  invitation: { name: 'Приглашение', icon: '✉' },
  rumor: { name: 'Слух', icon: '❝' },
  info: { name: 'Сведения', icon: '✎' },
  clue: { name: 'Улика', icon: '⚲' },
  item: { name: 'Предмет', icon: '⚱' },
  state: { name: 'Состояние', icon: '◐' },
  world: { name: 'Состояние мира', icon: '◎' },
};

// Окраска качественных состояний отношений
const REL_TONES = {
  'Доверие': 'good', 'Близость': 'good', 'Уважение': 'good', 'Расположение': 'good', 'Интерес': 'warm',
  'Любопытство': 'warm', 'Деловой интерес': 'warm', 'Тёплое знакомство': 'warm',
  'Раздражение': 'bad', 'Подозрение': 'bad', 'Разочарование': 'bad', 'Обида': 'bad',
  'Долг': 'duty', 'Терпит': 'neutral', 'Знакомы': 'neutral',
};
export function relTone(tag) {
  if (tag.startsWith('Знает')) return 'know';
  return REL_TONES[tag] || 'neutral';
}

export function relChip(tag) {
  return h('span', { class: `rel rel-${relTone(tag)}` }, tag);
}

export function lifetimeLabel(n) {
  if (n == null) return null;
  if (n >= 8) return `≈${Math.round(n / 4)} дн.`;
  if (n === 1) return 'до конца этой части дня';
  return `${n} ч. дня`;
}

export function cardEl(id, s, { onClick, selected, compact } = {}) {
  const def = R.getDef(id);
  const inst = s.cards[id];
  const t = TYPES[def.type] || { name: def.type, icon: '•' };
  const where = def.type === 'person' ? R.whereIs(s, id) : null;
  const life = inst?.lifetime != null ? lifetimeLabel(inst.lifetime) : null;
  const urgent = inst?.lifetime != null && inst.lifetime <= 1;
  return h('div', {
    class: `card type-${def.type}${selected ? ' selected' : ''}${inst?.fresh ? ' fresh' : ''}${compact ? ' compact' : ''}`,
    style: def.color ? { '--accent': def.color } : null,
    onClick: onClick ? () => onClick(id) : null,
    title: R.txt(def.title, s),
  },
  h('div', { class: 'card-head' },
    h('span', { class: 'card-icon' }, t.icon),
    h('span', { class: 'card-type' }, def.subtitle && def.type !== 'person' ? R.txt(def.subtitle, s) : t.name),
    inst?.count > 1 ? h('span', { class: 'card-count' }, '×' + inst.count) : null),
  h('div', { class: 'card-title' }, R.txt(def.title, s)),
  def.type === 'person' ? h('div', { class: 'card-sub' }, def.subtitle) : null,
  def.type === 'person' ? h('div', { class: 'card-rels' }, (s.rel[id] || []).map(relChip)) : null,
  where ? h('div', { class: 'card-where' }, '⌖ ' + R.cardTitle(where, s)) : null,
  life ? h('div', { class: `card-life${urgent ? ' urgent' : ''}` }, '⏳ ' + life) : null,
  );
}

export function changesList(changes, s) {
  if (!changes?.length) return null;
  const seen = new Set();
  const items = [];
  for (const c of changes) {
    const key = c.kind + ':' + c.id + ':' + (c.who || '') + ':' + (c.tag || '') + ':' + (c.add ?? '');
    if (seen.has(key)) continue;
    seen.add(key);
    if (c.kind === 'gain') {
      const d = R.getDef(c.id);
      items.push(h('li', { class: 'ch-gain' }, `+ ${R.txt(d?.title, s)}`, h('span', { class: 'ch-type' }, ` · ${TYPES[d?.type]?.name || ''}`)));
    } else if (c.kind === 'lose') {
      items.push(h('li', { class: 'ch-lose' }, `− ${R.cardTitle(c.id, s)}`));
    } else if (c.kind === 'expire') {
      items.push(h('li', { class: 'ch-expire' }, `⌛ ${R.cardTitle(c.id, s)} — исчезает`));
    } else if (c.kind === 'rel') {
      items.push(h('li', { class: 'ch-rel' }, `${R.cardTitle(c.who, s)}: `, c.add ? '+ ' : '− ', relChip(c.tag)));
    }
  }
  return h('ul', { class: 'changes' }, items);
}
