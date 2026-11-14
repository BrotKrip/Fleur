// ВРЕМЕННАЯ активность «Охота у акватории Морт».
// Заготовка будущей «рыбалки»: лодка, гарпуны, крупная тварь с отдельными частями тела,
// повреждение частей влияет и на бой, и на добычу. Графика — примитивы на canvas.

import { h } from '../ui/dom.js';

const W = 960, H = 540, SURFACE = 96;

const PARTS = {
  head: { name: 'головной щиток', dx: 72, dy: 0, r: 30, hp: 4, armored: true },
  body: { name: 'тело', dx: 0, dy: 0, r: 46, hp: Infinity },
  fin: { name: 'спинной плавник', dx: -6, dy: -46, r: 20, hp: 2 },
  tail: { name: 'хвост', dx: -92, dy: 6, r: 22, hp: 2 },
};

export const harpoon = {
  id: 'harpoon',
  title: 'Охота у акватории Морт',
  intro: 'A/D или ←/→ — двигать лодку. Клик — бросить гарпун. Ломать части выгодно в бою, но сломанная часть не попадёт в добычу. Временный режим.',

  mount(container, params, finish) {
    const big = !!params.big;
    const canvas = h('canvas', { width: W, height: H, class: 'act-canvas' });
    const hud = h('div', { class: 'act-hud' });
    const endPanel = h('div', { class: 'act-end hidden' });
    const retreatBtn = h('button', { class: 'btn ghost', onClick: () => end('retreat') }, 'Отступить');
    container.append(h('div', { class: 'act-canvas-wrap' }, canvas, endPanel), h('div', { class: 'act-bar' }, hud, retreatBtn));
    const g = canvas.getContext('2d');

    const st = {
      t: 0, timeLimit: 90,
      boat: { x: W / 2, hp: 3, hit: 0 },
      harpoons: big ? 12 : 10, reload: 0, shots: [],
      mouse: { x: W / 2, y: H / 2 },
      keys: {},
      c: {
        x: 200, y: 330, dir: 1, hp: big ? 16 : 10, maxHp: big ? 16 : 10, scale: big ? 1.35 : 1,
        mode: 'swim', attackIn: 6, flash: 0, stagger: 0, phase: Math.random() * 6,
        parts: Object.fromEntries(Object.entries(PARTS).map(([k, p]) => [k, { hp: p.hp, broken: false }])),
      },
      messages: [],
      ended: null,
    };

    window.__harpoon = st; // отладка из консоли

    const msg = (text) => { st.messages.push({ text, ttl: 2.6 }); if (st.messages.length > 4) st.messages.shift(); };

    function partPos(key) {
      const c = st.c, p = PARTS[key];
      return { x: c.x + p.dx * c.dir * c.scale, y: c.y + p.dy * c.scale, r: p.r * c.scale };
    }

    // ---------- Управление ----------
    const onKey = (e, down) => { st.keys[e.key.toLowerCase()] = down; };
    const kd = (e) => onKey(e, true), ku = (e) => onKey(e, false);
    window.addEventListener('keydown', kd);
    window.addEventListener('keyup', ku);
    const toLocal = (e) => {
      const r = canvas.getBoundingClientRect();
      return { x: (e.clientX - r.left) * (W / r.width), y: (e.clientY - r.top) * (H / r.height) };
    };
    canvas.addEventListener('mousemove', (e) => { st.mouse = toLocal(e); });
    canvas.addEventListener('mousedown', (e) => {
      if (st.ended) return;
      st.mouse = toLocal(e);
      if (st.harpoons <= 0 || st.reload > 0) return;
      const sx = st.boat.x, sy = SURFACE + 6;
      const dx = st.mouse.x - sx, dy = Math.max(10, st.mouse.y - sy);
      const len = Math.hypot(dx, dy);
      st.shots.push({ x: sx, y: sy, vx: (dx / len) * 760, vy: (dy / len) * 760, dist: 0 });
      st.harpoons--; st.reload = 0.55;
    });

    // ---------- Логика ----------
    function hitCreature(shot) {
      const c = st.c;
      for (const key of ['head', 'fin', 'tail', 'body']) {
        const pp = partPos(key);
        if (Math.hypot(shot.x - pp.x, shot.y - pp.y) > pp.r) continue;
        const part = c.parts[key];
        const def = PARTS[key];
        let dmg = 1;
        if (key === 'body') dmg = c.parts.head.broken ? 3 : 2;
        if (key !== 'body' && !part.broken) {
          part.hp--;
          if (part.hp <= 0) {
            part.broken = true;
            msg(`Сломан ${def.name}!`);
            if (key === 'tail') msg('Скат замедлился.');
            if (key === 'fin') msg('Скат потерял устойчивость.');
            if (key === 'head') msg('Щиток расколот — тело открыто.');
          } else msg(def.armored ? 'Гарпун скользнул по щитку.' : `Попадание: ${def.name}.`);
        } else if (key === 'body') msg('Попадание в тело.');
        if (def.armored && !part.broken) dmg = 0.5;
        c.hp -= dmg; c.flash = 0.15;
        if (key === 'head' && c.mode === 'charge') { c.mode = 'retreat'; c.stagger = 0.8; msg('Атака сорвана!'); }
        return true;
      }
      return false;
    }

    function update(dt) {
      st.t += dt;
      const b = st.boat, c = st.c;
      const dirKey = (st.keys.a || st.keys.arrowleft ? -1 : 0) + (st.keys.d || st.keys.arrowright ? 1 : 0);
      b.x = Math.max(60, Math.min(W - 60, b.x + dirKey * 240 * dt));
      b.hit = Math.max(0, b.hit - dt);
      st.reload = Math.max(0, st.reload - dt);

      for (const s of st.shots) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.dist += 760 * dt;
        if (!s.dead && hitCreature(s)) s.dead = true;
        if (s.dist > 560 || s.y > H || s.x < 0 || s.x > W) s.dead = true;
      }
      st.shots = st.shots.filter((s) => !s.dead);

      c.flash = Math.max(0, c.flash - dt);
      c.stagger = Math.max(0, c.stagger - dt);
      if (c.mode === 'dead') { c.y = Math.max(SURFACE + 40, c.y - 60 * dt); return; }

      const speedMul = (c.parts.tail.broken ? 0.55 : 1) * (big ? 0.9 : 1);
      const wobble = c.parts.fin.broken ? 26 : 10;
      if (c.mode === 'swim') {
        c.x += c.dir * 120 * speedMul * dt;
        c.phase += dt * (c.parts.fin.broken ? 3.2 : 1.6);
        c.y += Math.sin(c.phase) * wobble * dt * 3;
        c.y = Math.max(200, Math.min(H - 70, c.y));
        if (c.x > W - 110) c.dir = -1;
        if (c.x < 110) c.dir = 1;
        c.attackIn -= dt;
        if (c.attackIn <= 0) { c.mode = 'charge'; msg('Скат идёт на лодку!'); }
      } else if (c.mode === 'charge') {
        const tx = b.x, ty = SURFACE + 30;
        const dx = tx - c.x, dy = ty - c.y, d = Math.hypot(dx, dy);
        c.dir = dx >= 0 ? 1 : -1;
        const sp = 230 * speedMul;
        c.x += (dx / d) * sp * dt; c.y += (dy / d) * sp * dt;
        if (d < 50 * c.scale) {
          if (Math.abs(b.x - c.x) < 70 * c.scale) { b.hp--; b.hit = 0.6; msg(b.hp > 0 ? 'Удар в днище!' : 'Лодка перевернулась!'); }
          c.mode = 'retreat';
        }
        if (c.y < SURFACE + 34) c.mode = 'retreat';
      } else if (c.mode === 'retreat') {
        c.y += 150 * dt;
        c.x += c.dir * 60 * dt;
        if (c.y > 330) { c.mode = 'swim'; c.attackIn = 5 + Math.random() * 3 + (c.parts.fin.broken ? 2 : 0); }
      }
      c.x = Math.max(90, Math.min(W - 90, c.x));

      for (const m of st.messages) m.ttl -= dt;
      st.messages = st.messages.filter((m) => m.ttl > 0);

      if (c.hp <= 0) { c.mode = 'dead'; setTimeout(() => end('win'), 1100); }
      else if (b.hp <= 0) end('lost');
      else if (st.t >= st.timeLimit) end('escaped');
      else if (st.harpoons <= 0 && st.shots.length === 0 && !st.outOfAmmo) {
        st.outOfAmmo = true; msg('Гарпуны кончились.'); setTimeout(() => end('escaped'), 1600);
      }
    }

    // ---------- Отрисовка ----------
    function draw() {
      const c = st.c, b = st.boat;
      const sky = g.createLinearGradient(0, 0, 0, SURFACE);
      sky.addColorStop(0, '#bfe4ee'); sky.addColorStop(1, '#8cc7d6');
      g.fillStyle = sky; g.fillRect(0, 0, W, SURFACE);
      // южная стена города
      g.fillStyle = '#b8b7ae'; g.fillRect(0, 20, W, SURFACE - 20);
      g.fillStyle = '#2f8c86';
      for (let x = 40; x < W; x += 180) { g.fillRect(x, 8, 46, 14); g.fillRect(x + 14, 0, 18, 10); }
      const water = g.createLinearGradient(0, SURFACE, 0, H);
      water.addColorStop(0, '#2a7f9e'); water.addColorStop(1, '#071d2c');
      g.fillStyle = water; g.fillRect(0, SURFACE, W, H - SURFACE);
      // блики
      g.strokeStyle = 'rgba(255,255,255,0.08)';
      for (let i = 0; i < 9; i++) {
        const y = SURFACE + 40 + i * 48, off = Math.sin(st.t * 0.7 + i) * 30;
        g.beginPath(); g.moveTo(0, y); g.bezierCurveTo(W / 3, y + off, (2 * W) / 3, y - off, W, y); g.stroke();
      }

      // тварь
      g.save();
      g.translate(c.x, c.y); g.scale(c.dir * c.scale, c.scale);
      const base = c.flash > 0 ? '#ffffff' : (c.mode === 'dead' ? '#5a6670' : '#3d5c6e');
      // хвост
      if (!c.parts.tail.broken) {
        g.fillStyle = base; g.beginPath(); g.moveTo(-50, 0); g.lineTo(-115, -6); g.lineTo(-120, 16); g.closePath(); g.fill();
        g.fillStyle = '#d9d2b5'; g.beginPath(); g.moveTo(-112, -4); g.lineTo(-132, 4); g.lineTo(-112, 10); g.fill();
      } else { g.fillStyle = '#7a2b2b'; g.fillRect(-62, -4, 12, 12); }
      // тело
      g.fillStyle = base; g.beginPath(); g.ellipse(0, 0, 70, 40, 0, 0, Math.PI * 2); g.fill();
      g.fillStyle = 'rgba(160,220,230,0.25)'; g.beginPath(); g.ellipse(-4, 12, 54, 18, 0, 0, Math.PI * 2); g.fill();
      // плавник
      if (!c.parts.fin.broken) { g.fillStyle = '#2b4656'; g.beginPath(); g.moveTo(-28, -32); g.lineTo(4, -70); g.lineTo(18, -34); g.closePath(); g.fill(); }
      else { g.fillStyle = '#7a2b2b'; g.fillRect(-10, -40, 16, 8); }
      // головной щиток
      g.fillStyle = c.parts.head.broken ? '#6d4a3a' : '#8fb3a6';
      g.beginPath(); g.ellipse(68, -2, 34, 28, 0, 0, Math.PI * 2); g.fill();
      if (!c.parts.head.broken) { g.strokeStyle = '#cde3d6'; g.lineWidth = 2; g.beginPath(); g.arc(68, -2, 20, -1.2, 1.2); g.stroke(); }
      g.fillStyle = '#ffeb8a'; g.beginPath(); g.arc(84, -8, 4, 0, Math.PI * 2); g.fill();
      g.restore();

      // гарпуны
      g.strokeStyle = '#e8d9a8'; g.lineWidth = 3;
      for (const s of st.shots) {
        const len = Math.hypot(s.vx, s.vy);
        g.beginPath(); g.moveTo(s.x - (s.vx / len) * 26, s.y - (s.vy / len) * 26); g.lineTo(s.x, s.y); g.stroke();
        g.strokeStyle = 'rgba(232,217,168,0.25)'; g.lineWidth = 1;
        g.beginPath(); g.moveTo(b.x, SURFACE); g.lineTo(s.x, s.y); g.stroke();
        g.strokeStyle = '#e8d9a8'; g.lineWidth = 3;
      }

      // лодка
      g.save(); g.translate(b.x, SURFACE);
      if (b.hit > 0) g.rotate(Math.sin(st.t * 40) * 0.08);
      g.fillStyle = '#5b3a24'; g.beginPath(); g.moveTo(-54, -14); g.lineTo(54, -14); g.lineTo(40, 6); g.lineTo(-40, 6); g.closePath(); g.fill();
      g.fillStyle = '#1e2c4f'; g.fillRect(-6, -40, 12, 26); // Флёр
      g.fillStyle = '#c9a94a'; g.fillRect(-14, -44, 28, 5); // шляпа
      g.fillStyle = '#fff'; g.fillRect(8, -50, 3, 9); // перо
      g.restore();

      // прицел
      if (!st.ended) {
        g.strokeStyle = st.reload > 0 || st.harpoons <= 0 ? 'rgba(255,255,255,0.25)' : 'rgba(255,240,190,0.85)';
        g.lineWidth = 1.5; g.beginPath(); g.arc(st.mouse.x, st.mouse.y, 12, 0, Math.PI * 2); g.stroke();
        g.setLineDash([4, 6]); g.beginPath(); g.moveTo(b.x, SURFACE + 6); g.lineTo(st.mouse.x, st.mouse.y); g.stroke(); g.setLineDash([]);
      }

      // сообщения
      g.font = '16px Georgia, serif'; g.textAlign = 'center';
      st.messages.forEach((m, i) => {
        g.fillStyle = `rgba(255,248,225,${Math.min(1, m.ttl)})`;
        g.fillText(m.text, W / 2, H - 24 - (st.messages.length - 1 - i) * 22);
      });
    }

    function renderHud() {
      const c = st.c;
      const parts = Object.entries(PARTS).filter(([k]) => k !== 'body')
        .map(([k, p]) => `${p.name}: ${c.parts[k].broken ? 'сломан' : 'цел'}`).join(' · ');
      hud.textContent = `Гарпуны: ${st.harpoons} · Лодка: ${'♥'.repeat(Math.max(0, st.boat.hp))} · Скат: ${Math.max(0, Math.ceil((c.hp / c.maxHp) * 100))}% · ${parts} · Время: ${Math.max(0, Math.ceil(st.timeLimit - st.t))} с`;
    }

    // ---------- Завершение ----------
    function end(outcome) {
      if (st.ended) return;
      const c = st.c;
      const loot = [];
      const lines = [];
      if (outcome === 'win') {
        loot.push('it_skate_meat');
        if (big) loot.push('it_skate_meat', 'it_skate_pearl');
        if (!c.parts.fin.broken) loot.push('it_skate_fin'); else lines.push('Плавник изорван гарпунами — в добычу не годится.');
        if (!c.parts.head.broken) loot.push('it_skate_plate'); else lines.push('Головной щиток расколот.');
        if (!c.parts.tail.broken) loot.push('it_skate_spine'); else lines.push('Хвост с шипом потерян.');
        lines.unshift(big ? 'Крупный панцирный скат поднят к борту. Лодочник на причале перестанет врать — теперь ему будет чем хвастаться по-настоящему.' : 'Панцирный скат поднят к борту.');
      }
      st.ended = { outcome, loot, summary: lines.join(' ') };
      const titles = { win: 'Добыча', escaped: 'Ушёл', lost: 'Лодка перевернулась', retreat: 'Отступление' };
      endPanel.classList.remove('hidden');
      endPanel.replaceChildren(...[
        h('h3', {}, titles[outcome]),
        st.ended.summary ? h('p', {}, st.ended.summary) : null,
        h('button', { class: 'btn primary', onClick: () => finish(st.ended) }, 'Вернуться на причал')].filter(Boolean));
      retreatBtn.disabled = true;
    }

    // ---------- Цикл ----------
    let last = performance.now(), raf;
    const loop = (now) => {
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      if (!st.ended || st.c.mode === 'dead') update(dt);
      draw(); renderHud();
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('keydown', kd);
      window.removeEventListener('keyup', ku);
    };
  },
};
