import { Game } from './game.js';

const game = new Game(document.getElementById('app'), document.getElementById('modal-root'));
game.start();
// Для отладки из консоли браузера
window.__game = game;
