// Реестр контента. Новые карты, действия, события и сцены подключаются здесь.

import { cards } from './cards.js';
import { characters } from './characters.js';
import { actions, activityResults } from './actions.js';
import { events } from './events.js';
import { charlotte_nectar } from './scenes/charlotte_nectar.js';

for (const [id, c] of Object.entries(cards)) c.id = id;
for (const [id, a] of Object.entries(actions)) a.id = id;
for (const [id, e] of Object.entries(events)) e.id = id;

export const CONTENT = {
  cards,
  characters,
  actions,
  events,
  activityResults,
  scenes: { charlotte_nectar },

  // Говорящие в VN-сценах, которые не являются картами (сам Флёр и т.п.)
  speakers: {
    fleur: { title: 'Флёр', color: '#c9a94a' },
  },

  // Временные фоны (градиенты) для VN и панели мест
  backgrounds: {
    apartment: { label: 'Квартира, улица Изумрудных Фонарей', css: 'linear-gradient(160deg,#1d2a4a 0%,#3b2f4f 55%,#6b4a2f 100%)' },
    apartment_night: { label: 'Квартира, ночь', css: 'linear-gradient(170deg,#070b18 0%,#16203b 60%,#3a2a1a 100%)' },
    vasari: { label: 'Пассаж Вазари', css: 'linear-gradient(170deg,#7fc6d8 0%,#3a8ea6 45%,#c9a94a 100%)' },
    lutes: { label: 'Кафе «Лютес»', css: 'linear-gradient(165deg,#d9c7a3 0%,#8a6a46 55%,#3a6d7a 100%)' },
    tiori: { label: 'Дом Тиори', css: 'linear-gradient(160deg,#f0d78a 0%,#b5543a 60%,#2a1f2a 100%)' },
    docks: { label: 'Нижние причалы', css: 'linear-gradient(180deg,#9fd3e0 0%,#2c6e8a 50%,#0d2a3d 100%)' },
    steambird: { label: 'Редакция «Паровой птицы»', css: 'linear-gradient(160deg,#cfc6b8 0%,#7a2f3a 60%,#22181c 100%)' },
  },

  start: {
    cards: [
      'loc_apartment', 'loc_vasari', 'loc_lutes', 'loc_tiori', 'loc_docks',
      'char_josie', 'char_charlotte', 'char_tiori', 'char_clorinde', 'char_marcel',
      'sl_family', 'sl_eye',
      'it_rapier', 'it_hairpin',
      'st_hangover',
    ],
    effects: [],
  },
};
