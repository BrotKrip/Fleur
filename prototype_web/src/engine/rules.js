// Ядро правил: условия, эффекты, течение времени, события мира.
// Всё состояние игры — простой JSON (сохраняется как есть), контент — статичные определения в src/content.

import { CONTENT } from '../content/index.js';

export const PHASES = ['Утро', 'День', 'Вечер', 'Ночь'];
export const PHASE_KEYS = ['morning', 'day', 'evening', 'night'];

export const absTime = (s) => (s.day - 1) * 4 + s.phase;
export const phaseKey = (s) => PHASE_KEYS[s.phase];

export function getDef(id) {
  return CONTENT.cards[id] || CONTENT.characters[id] || null;
}

export function txt(t, s, ctx) {
  return typeof t === 'function' ? t(s, ctx || {}) : (t ?? '');
}

export function cardTitle(id, s) {
  const d = getDef(id);
  return d ? txt(d.title, s) : id;
}

// ---------- Карты ----------

export function addCard(s, id, opts = {}, api) {
  const def = getDef(id);
  if (!def) { console.warn('Неизвестная карта', id); return false; }
  const lifetime = opts.lifetime ?? def.lifetime ?? null;
  const ex = s.cards[id];
  if (ex) {
    if (def.stack) ex.count = (ex.count || 1) + (opts.count || 1);
    if (lifetime != null) ex.lifetime = Math.max(ex.lifetime ?? 0, lifetime);
    if (def.stack) api?.changes.push({ kind: 'gain', id });
    return false;
  }
  s.cards[id] = { id, lifetime, count: opts.count || 1, fresh: true, since: absTime(s) };
  if (def.type === 'person' && !s.rel[id]) s.rel[id] = [...(def.rel || [])];
  api?.changes.push({ kind: 'gain', id });
  return true;
}

export function removeCard(s, id, api) {
  if (!s.cards[id]) return false;
  const def = getDef(id);
  if (def?.stack && s.cards[id].count > 1) s.cards[id].count--;
  else delete s.cards[id];
  api?.changes.push({ kind: 'lose', id });
  return true;
}

// ---------- Где находятся люди ----------

export function whereIs(s, pid) {
  const w = s.whereabouts[pid];
  if (w && (w.until == null || w.until > absTime(s))) return w.loc;
  const def = CONTENT.characters[pid];
  if (!def?.schedule) return null;
  const sch = typeof def.schedule === 'function' ? def.schedule(s) : def.schedule;
  return sch?.[phaseKey(s)] || null;
}

export function peopleAt(s, loc) {
  return Object.keys(s.cards).filter((id) => getDef(id)?.type === 'person' && whereIs(s, id) === loc);
}

// ---------- Условия ----------

function resolve(v, ctx) {
  if (typeof v !== 'string' || v[0] !== '$') return v;
  const key = v.slice(1);
  if (key === 'here') return ctx.here;
  return ctx.slots?.[key] ?? null;
}

export function test(c, s, ctx = {}) {
  if (c == null) return true;
  if (Array.isArray(c)) return c.every((x) => test(x, s, ctx));
  if (typeof c === 'function') return !!c(s, ctx);
  for (const [k, v] of Object.entries(c)) {
    switch (k) {
      case 'all': if (!v.every((x) => test(x, s, ctx))) return false; break;
      case 'any': if (!v.some((x) => test(x, s, ctx))) return false; break;
      case 'not': if (test(v, s, ctx)) return false; break;
      case 'flag': if (![].concat(v).every((f) => s.flags[f])) return false; break;
      case 'noFlag': if ([].concat(v).some((f) => s.flags[f])) return false; break;
      case 'has': if (![].concat(v).every((id) => s.cards[resolve(id, ctx)])) return false; break;
      case 'lacks': if ([].concat(v).some((id) => s.cards[resolve(id, ctx)])) return false; break;
      case 'phase': if (![].concat(v).includes(phaseKey(s))) return false; break;
      case 'day': if (s.day !== v) return false; break;
      case 'dayGte': if (s.day < v) return false; break;
      case 'rel': { const [p, tag] = v; if (!(s.rel[resolve(p, ctx)] || []).includes(tag)) return false; break; }
      case 'noRel': { const [p, tag] = v; if ((s.rel[resolve(p, ctx)] || []).includes(tag)) return false; break; }
      case 'present': { const [p, loc] = v; if (whereIs(s, resolve(p, ctx)) !== resolve(loc, ctx)) return false; break; }
      case 'slot': { const [name, id] = v; if (ctx.slots?.[name] !== id) return false; break; }
      case 'slotFilled': if (!ctx.slots?.[v]) return false; break;
      case 'slotEmpty': if (ctx.slots?.[v]) return false; break;
      case 'ctx': { const [key, val] = v; if (ctx[key] !== val) return false; break; }
      case 'counterGte': { const [name, n] = v; if ((s.counters[name] || 0) < n) return false; break; }
      case 'fired': if (!s.fired[v]) return false; break;
      case 'chance': if (Math.random() >= v) return false; break;
      default: console.warn('Неизвестное условие', k);
    }
  }
  return true;
}

// ---------- Эффекты ----------

const pairs = (v) => (Array.isArray(v[0]) ? v : [v]);

export function apply(effects, s, ctx = {}, api) {
  if (!effects) return;
  for (const e of [].concat(effects)) {
    if (typeof e === 'function') { e(s, ctx, api); continue; }
    if (e.if !== undefined) {
      apply(test(e.if, s, ctx) ? e.then : e.else, s, ctx, api);
      continue;
    }
    for (const [k, v] of Object.entries(e)) {
      switch (k) {
        case 'add':
          for (const it of [].concat(v)) {
            if (typeof it === 'string') addCard(s, resolve(it, ctx), {}, api);
            else addCard(s, resolve(it.id, ctx), it, api);
          }
          break;
        case 'remove': for (const id of [].concat(v)) removeCard(s, resolve(id, ctx), api); break;
        case 'flag': for (const f of [].concat(v)) s.flags[f] = true; break;
        case 'unflag': for (const f of [].concat(v)) delete s.flags[f]; break;
        case 'counter': for (const [name, d] of pairs(v)) s.counters[name] = (s.counters[name] || 0) + d; break;
        case 'relAdd':
          for (const [p0, tag] of pairs(v)) {
            const p = resolve(p0, ctx); const list = (s.rel[p] ||= []);
            if (!list.includes(tag)) { list.push(tag); api?.changes.push({ kind: 'rel', who: p, tag, add: true }); }
          }
          break;
        case 'relRemove':
          for (const [p0, tag] of pairs(v)) {
            const p = resolve(p0, ctx); const list = s.rel[p] || [];
            const i = list.indexOf(tag);
            if (i >= 0) { list.splice(i, 1); api?.changes.push({ kind: 'rel', who: p, tag, add: false }); }
          }
          break;
        case 'log': log(s, txt(v, s, ctx)); break;
        case 'notice': s.notices.push({ title: txt(v.title, s, ctx), text: txt(v.text, s, ctx), kind: v.kind || 'event' }); break;
        case 'scene': s.queue.push({ type: 'scene', id: typeof v === 'string' ? v : v.id, ctx: v.ctx || {} }); break;
        case 'activity': s.queue.push({ type: 'activity', id: v.id, params: v.params || {}, onResult: v.onResult || null }); break;
        case 'schedule': s.scheduled.push({ event: v.event, at: absTime(s) + (v.in ?? 1) }); break;
        case 'event': fireEvent(s, v, api, true); break;
        case 'wait': advance(s, v, api); break; // продвинуть время на v частей дня
        case 'place': {
          // { who, loc, for } — переопределить местонахождение человека на N частей дня (или навсегда)
          s.whereabouts[resolve(v.who, ctx)] = { loc: v.loc, until: v.for == null ? null : absTime(s) + v.for };
          break;
        }
        case 'then': case 'else': break;
        default: console.warn('Неизвестный эффект', k);
      }
    }
  }
}

export function log(s, text, kind = 'text') {
  if (!text) return;
  s.log.push({ t: absTime(s), day: s.day, phase: s.phase, text, kind });
  if (s.log.length > 200) s.log.splice(0, s.log.length - 200);
}

// ---------- Время ----------

// Продвигает время на n частей дня. Если по ходу возникла сцена/активность (s.queue),
// продвижение останавливается: мир «перебил» планы игрока (например, звонок в дверь посреди сна).
export function advance(s, n, api) {
  const queued = s.queue.length;
  for (let i = 0; i < n; i++) {
    step(s, api);
    if (s.queue.length > queued && i < n - 1) {
      log(s, 'Планы пришлось прервать.', 'system');
      break;
    }
  }
}

function step(s, api) {
  const wasNight = s.phase === 3;
  s.phase++;
  if (s.phase > 3) { s.phase = 0; s.day++; }

  if (wasNight) {
    if (!s.flags._slept) {
      addCard(s, 'st_tired', {}, api);
      log(s, 'Ночь прошла без сна. Это будет заметно.', 'system');
    }
    delete s.flags._slept;
  }

  // Карты с ограниченным сроком жизни
  for (const inst of Object.values({ ...s.cards })) {
    if (inst.lifetime == null) continue;
    inst.lifetime--;
    if (inst.lifetime <= 0) {
      const def = getDef(inst.id);
      delete s.cards[inst.id];
      api?.changes.push({ kind: 'expire', id: inst.id });
      if (def?.expireText) log(s, txt(def.expireText, s), 'expire');
      apply(def?.onExpire, s, {}, api);
    }
  }

  checkEvents(s, api);
}

// ---------- События ----------

export function checkEvents(s, api) {
  const t = absTime(s);
  const due = s.scheduled.filter((x) => x.at <= t);
  s.scheduled = s.scheduled.filter((x) => x.at > t);
  for (const d of due) fireEvent(s, d.event, api, true);

  for (const ev of Object.values(CONTENT.events)) {
    if (ev.manual) continue;
    if (ev.repeat) {
      if (s.fired[ev.id] && t - (s.firedAt[ev.id] ?? -999) < (ev.cooldown ?? 4)) continue;
    } else if (s.fired[ev.id]) continue;
    if (!test(ev.when, s, {})) continue;
    if (ev.chance != null && Math.random() >= ev.chance) continue;
    fireEvent(s, ev.id, api);
  }
}

export function fireEvent(s, id, api, forced = false) {
  const ev = CONTENT.events[id];
  if (!ev) { console.warn('Неизвестное событие', id); return; }
  if (forced && ev.when && !test(ev.when, s, {})) return;
  s.fired[id] = (s.fired[id] || 0) + 1;
  s.firedAt[id] = absTime(s);
  if (ev.title || ev.text) s.notices.push({ title: txt(ev.title, s), text: txt(ev.text, s), kind: ev.kind || 'event' });
  if (ev.logText) log(s, txt(ev.logText, s), 'event');
  apply(ev.effects, s, {}, api);
}

// ---------- Действия ----------

export function isLocation(id) { return getDef(id)?.type === 'location'; }

export function actionsFor(s, where) {
  return Object.values(CONTENT.actions).filter((a) => {
    const matches = a.at === where || a.on === where || (a.at === '*' && isLocation(where));
    if (!matches) return false;
    return test(a.visible, s, { here: isLocation(where) ? where : (a.here || null) });
  });
}

export function actionCtx(a, where, slots = {}) {
  return { here: a.here || (isLocation(where) ? where : null), slots, actionId: a.id };
}

export function slotCandidates(slot, s, ctx) {
  return Object.keys(s.cards).filter((id) => {
    const d = getDef(id);
    if (!d) return false;
    if (slot.types && !slot.types.includes(d.type)) return false;
    if (slot.ids && !slot.ids.includes(id)) return false;
    if (slot.tags && !slot.tags.every((t) => d.tags?.includes(t))) return false;
    if (slot.present && whereIs(s, id) !== ctx.here) return false;
    if (slot.filter && !slot.filter(id, s, ctx)) return false;
    return true;
  });
}

export function costOf(a, s) {
  const c = a.cost ?? 1;
  return c === 'untilMorning' ? 4 - s.phase : c;
}

// Можно ли выполнить действие. Возвращает { ok, reason }.
export function canDo(a, s, ctx) {
  if (a.once && s.flags['done:' + a.id]) return { ok: false, reason: 'Уже сделано.' };
  if (a.daily && s.doneDay[a.id] === s.day) return { ok: false, reason: 'Сегодня уже было.' };
  if (a.phases && !a.phases.includes(phaseKey(s))) {
    const names = a.phases.map((p) => PHASES[PHASE_KEYS.indexOf(p)].toLowerCase()).join(', ');
    return { ok: false, reason: `Доступно: ${names}.` };
  }
  for (const r of [].concat(a.req || [])) {
    const cond = r.cond ?? r;
    if (!test(cond, s, ctx)) return { ok: false, reason: r.reason || 'Условия не выполнены.' };
  }
  for (const sl of a.slots || []) {
    if (sl.required && !ctx.slots?.[sl.id]) return { ok: false, reason: `Нужно: ${sl.label.toLowerCase()}.` };
  }
  return { ok: true };
}

// Выполнить действие. Возвращает { title, text } для показа результата.
export function perform(a, s, ctx, api) {
  const outcome = (a.outcomes || []).find((o) => test(o.when, s, ctx)) || {};
  const text = txt(outcome.text, s, ctx);
  log(s, `${a.title}. ${text}`.trim(), 'action');
  apply(outcome.effects, s, ctx, api);
  if (a.once) s.flags['done:' + a.id] = true;
  if (a.daily) s.doneDay[a.id] = s.day;
  if (outcome.sleep || a.sleep) s.flags._slept = true;
  const cost = outcome.cost ?? costOf(a, s);
  if (cost === 'untilMorning') advance(s, 4 - s.phase, api);
  else if (cost > 0) advance(s, cost, api);
  return { title: txt(outcome.title, s, ctx) || a.title, text };
}

export function markSeen(s) {
  for (const c of Object.values(s.cards)) c.fresh = false;
}
