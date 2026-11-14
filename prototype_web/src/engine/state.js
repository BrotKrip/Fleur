// Создание нового состояния, сохранение и загрузка, настройки.

import { CONTENT } from '../content/index.js';
import { addCard, apply, checkEvents } from './rules.js';

export const SAVE_VERSION = 1;
const SAVE_PREFIX = 'fleur.save.';
const SETTINGS_KEY = 'fleur.settings';
export const SLOTS = ['auto', '1', '2', '3', '4', '5'];

export function newState() {
  const s = {
    version: SAVE_VERSION,
    day: 1,
    phase: 0,
    cards: {},        // id -> { id, lifetime, count, fresh, since }
    rel: {},          // personId -> [качественные состояния отношений]
    flags: {},
    counters: {},
    whereabouts: {},  // personId -> { loc, until }
    scheduled: [],    // [{ event, at }]
    fired: {},        // eventId -> сколько раз
    firedAt: {},
    doneDay: {},      // actionId -> день последнего выполнения (для daily)
    notices: [],      // всплывающие сообщения о событиях
    queue: [],        // ожидающие сцены и активности
    log: [],
  };
  const api = { changes: [] };
  for (const id of CONTENT.start.cards) addCard(s, id, {}, api);
  apply(CONTENT.start.effects, s, {}, api);
  checkEvents(s, api);
  return s;
}

// ---------- Сохранения ----------

function storage() {
  try { return window.localStorage; } catch { return null; }
}

export function writeSave(slot, state) {
  const ls = storage(); if (!ls) return false;
  const payload = { version: SAVE_VERSION, savedAt: Date.now(), day: state.day, phase: state.phase, state };
  try { ls.setItem(SAVE_PREFIX + slot, JSON.stringify(payload)); return true; } catch (e) { console.error(e); return false; }
}

export function readSave(slot) {
  const ls = storage(); if (!ls) return null;
  try {
    const raw = ls.getItem(SAVE_PREFIX + slot);
    if (!raw) return null;
    const data = JSON.parse(raw);
    if (data.version !== SAVE_VERSION) return { ...data, incompatible: true };
    return data;
  } catch { return null; }
}

export function deleteSave(slot) {
  try { storage()?.removeItem(SAVE_PREFIX + slot); } catch { /* ignore */ }
}

export function listSaves() {
  return SLOTS.map((slot) => ({ slot, data: readSave(slot) }));
}

export function hasAnySave() {
  return SLOTS.some((slot) => readSave(slot) && !readSave(slot).incompatible);
}

export function latestSave() {
  let best = null;
  for (const { slot, data } of listSaves()) {
    if (data && !data.incompatible && (!best || data.savedAt > best.data.savedAt)) best = { slot, data };
  }
  return best;
}

// ---------- Настройки ----------

export const DEFAULT_SETTINGS = {
  textSpeed: 45,     // символов в секунду, 0 — мгновенно
  fontScale: 1,
  autosave: true,
  volume: 0.7,       // заготовка под звук
  showHints: true,
};

export function loadSettings() {
  try {
    const raw = storage()?.getItem(SETTINGS_KEY);
    return { ...DEFAULT_SETTINGS, ...(raw ? JSON.parse(raw) : {}) };
  } catch { return { ...DEFAULT_SETTINGS }; }
}

export function saveSettings(st) {
  try { storage()?.setItem(SETTINGS_KEY, JSON.stringify(st)); } catch { /* ignore */ }
}
