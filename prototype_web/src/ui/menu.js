// Главное меню.
import { h } from './dom.js';
import { latestSave } from '../engine/state.js';

export class MainMenu {
  constructor(game) { this.game = game; }

  mount(root) {
    const g = this.game;
    const latest = latestSave();
    const btn = (label, fn, cls = '') => h('button', { class: 'btn wide ' + cls, onClick: fn }, label);
    this.el = h('div', { class: 'menu-screen' },
      h('div', { class: 'menu-water' }),
      h('div', { class: 'menu-panel' },
        h('div', { class: 'menu-kicker' }, 'Кур-де-Фонтейн'),
        h('h1', {}, 'Шевалье де ла Флёр'),
        h('div', { class: 'menu-sub' }, 'Коллекционер прекрасных мгновений'),
        h('div', { class: 'menu-list' },
          latest ? btn('Продолжить', () => g.continueGame(), 'primary') : null,
          btn('Новая игра', () => {
            if (latest) g.modals.confirm('Начать новую игру? Сохранения останутся в ячейках, но автосохранение будет перезаписано.', () => g.newGame());
            else g.newGame();
          }, latest ? '' : 'primary'),
          btn('Загрузить', () => g.modals.saveLoad('load')),
          btn('Настройки', () => g.modals.settings())),
        h('div', { class: 'menu-foot muted' }, 'Ранний каркас · фанатский проект по миру Genshin Impact')));
    root.append(this.el);
  }

  destroy() {}
}
