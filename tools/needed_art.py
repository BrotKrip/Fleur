# Собирает единый список недостающей графики: портреты, эмоции, образы, фоны.
# Запуск из корня репозитория: python tools/needed_art.py
# Результат: fleur/assets/art/NEEDED_ART.md
import glob
import json
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..", "fleur")
DATA = os.path.join(ROOT, "data")
ART = os.path.join(ROOT, "assets", "art")
CH = os.path.join(ART, "characters")
BG = os.path.join(ART, "backgrounds")
OUT = os.path.join(ART, "NEEDED_ART.md")

# Описания фонов, которых ещё нет. Ключ — id фона из сцен.
BG_NOTES = {
    "berill_ridge": "Восточный склон Берилла за последней межой. Белый известняк, длинные правильные дуги холмов, похожие на рёбра огромного существа, наполовину ушедшего в землю. Внизу маленькие ряды лоз и крыши поместья. День, ветер, сухая трава.",
    "expedition_camp": "Ночёвка под загнутым каменным ребром: костёр, тюки, котелок, две палатки, крупные низкие звёзды. Тёплый свет огня снизу, холодный сверху. Вызывается с профилем night.",
    "elynas_cave": "Вход в кости Элинаса. Расщелина переходит в гладкие слоистые стены, похожие на срез старого пня; над головой изгиб, как внутренняя сторона ребра. Фонарь мелюзины, тёплые охристые тона.",
    "elynas_heart": "«Первый красный зал». Стены с красноватым отливом, мягкие на вид. На одной стене светящаяся сама собой картина: море и солнце странного тёплого цвета, крупные мазки. В дальней стене застряли обломки старых механизмов. Над входом на ребре выцарапан нарцисс, переплетённый с крестом.",
    "meropide_infirmary": "Лазарет крепости Меропид: тесная тёплая комната под водой, иллюминатор с мутной водой и проплывающей рыбёшкой, койки, корзинка медсестры с нитками, стул со спинкой для пальто посетителя.",
    "meropide_office": "Кабинет герцога Ризли в Меропиде: тяжёлый стол, чайник на грелке, широкий таз за креслом, стулья для посетителей, металл и заклёпки крепости.",
    "chevreuse_home": "Две комнаты Шеврёз над скобяной лавкой. Мундиры на спинках стульев, одна кружка, тарелка с крошками, стопка рапортов под утюгом. Второго стула нет — табурет, на нём сапоги. Кровать, на которой она сидит в мундире. Вечер, одна лампа.",
}

# Подмены, которые просто дают другое имя тому же месту. Рисовать отдельно не нужно.
PLAIN_RENAMES = {"lutes", "tiori", "apartment_morning", "apartment_evening", "apartment_night", "vasari", "docks", "docks_night", "debor", "steambird"}

PEOPLE_NOTES = {
    "char_jakob": "Выцветшие светлые волосы, гладкое лицо без возраста (на вид лет 35), тёмный дорожный плащ, карманные часы на цепочке. Спокойный, вежливый, взгляд старше лица.",
    "npc_farida": "Наёмница-пустынница из Сумеру: выгоревшая накидка, тёмные волосы узлом, нож на поясе, обветренное лицо.",
    "npc_pelagie": "Мелюзина из Меруси: зелёная курточка, жетон на шнурке на шее, фонарь в руке.",
}


def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


aliases = load(os.path.join(DATA, "world.json"))["mood_aliases"]
people = {}
for p in glob.glob(os.path.join(DATA, "characters", "*.json")) + [os.path.join(DATA, "characters.json")]:
    for k, v in load(p).items():
        if isinstance(v, dict) and v.get("type") == "person":
            people[k] = v

art_gd = open(os.path.join(ROOT, "ui", "art.gd"), encoding="utf-8").read()
block = art_gd.split("const BACKGROUNDS := {", 1)[1].split("\n}", 1)[0]
bg_alias = dict(re.findall(r'"([^"]+)":\s*"([^"]+)"', block))


def title(pid):
    v = people.get(pid, {})
    t = v.get("title", pid)
    if isinstance(t, list):
        t = t[-1].get("text", pid)
    return t


def text(pid):
    v = people.get(pid, {})
    t = v.get("text", "")
    if isinstance(t, list):
        t = t[0].get("text", "") if t else ""
    sub = v.get("subtitle", "")
    return (sub + ". " if sub else "") + t


def mood_file(m):
    m = m.strip().lower()
    f = aliases.get(m, m)
    return f if re.match(r"^[a-z_]+$", f) else None


def has_base(pid):
    return os.path.exists(os.path.join(CH, pid + ".png")) or os.path.exists(os.path.join(CH, pid, "neutral.png"))


def has_mood(pid, f):
    return os.path.exists(os.path.join(CH, pid, f + ".png")) or os.path.exists(os.path.join(CH, pid + "_" + f + ".png"))


def has_look(pid, look, f="neutral"):
    return os.path.exists(os.path.join(CH, pid, "looks", look, f + ".png"))


used = {}          # pid -> set(scene)
need_mood = {}     # pid -> {file: [mood, set(scene)]}
need_look = {}     # (pid, look) -> {file: set(scene)}
bgs = {}           # bg id -> set(scene)

for p in sorted(glob.glob(os.path.join(DATA, "scenes", "*.scene"))):
    sc = os.path.basename(p)[:-6]
    look = {}
    for line in open(p, encoding="utf-8"):
        line = line.rstrip("\n")
        m = re.match(r"^@bg (\S+)", line)
        if m:
            bgs.setdefault(m.group(1), set()).add(sc)
            continue
        m = re.match(r"^@look (\S+)(?: (\S+))?", line)
        if m:
            look[m.group(1)] = m.group(2) or ""
            continue
        pid = mood = None
        m = re.match(r"^@show (\S+)(?: \S+)?(?: (\S+))?", line)
        if m:
            pid, mood = m.group(1), m.group(2)
        m = m or None
        m2 = re.match(r"^@mood (\S+) (\S+)", line)
        if m2:
            pid, mood = m2.groups()
        m3 = re.match(r"^([a-z_]+)(?: \[([^\]]+)\])?: ", line)
        if m3 and m3.group(1) not in ("fleur",):
            pid, mood = m3.group(1), m3.group(2)
        if not pid or pid in ("N", "fleur"):
            continue
        used.setdefault(pid, set()).add(sc)
        f = mood_file(mood) if mood else None
        lk = look.get(pid, "")
        if lk:
            ff = f or "neutral"
            if not has_look(pid, lk, ff):
                need_look.setdefault((pid, lk), {}).setdefault(ff, set()).add(sc)
            continue
        if f and f != "neutral" and not has_mood(pid, f):
            need_mood.setdefault(pid, {}).setdefault(f, [mood, set()])[1].add(sc)

# Портрет нужен и тем, кто появляется только карточкой на столе.
for pid in people:
    used.setdefault(pid, set())

# Фоны локаций.
for k, v in load(os.path.join(DATA, "cards.json")).items():
    if isinstance(v, dict) and v.get("bg"):
        bgs.setdefault(v["bg"], set()).add("карточка " + k)


def short(scs, n=6):
    s = sorted(scs)
    return ", ".join(s[:n]) + (f" и ещё {len(s) - n}" if len(s) > n else "")


no_base = sorted(pid for pid in used if not has_base(pid) and (pid in people or used[pid]))
bg_missing, bg_alias_used = [], []
for b, scs in sorted(bgs.items()):
    if os.path.exists(os.path.join(BG, b + ".png")):
        continue
    if b in PLAIN_RENAMES:
        continue
    (bg_alias_used if b in bg_alias else bg_missing).append((b, scs))

out = []
w = out.append
w("# Недостающая графика «Послевкусия»")
w("")
w("Единый список. Собирается скриптом `tools/needed_art.py` прямо по сценам, карточкам и папкам с артом, поэтому всегда отражает текущее состояние. Перезапуск: `python tools/needed_art.py` из корня репозитория.")
w("")
w("Пути: портрет — `assets/art/characters/<id>.png` или `<id>/neutral.png`; эмоция — `<id>/<эмоция>.png`; сценический образ — `<id>/looks/<образ>/<эмоция>.png`; фон — `assets/art/backgrounds/<id>.png`.")
w("")
tot_m = sum(len(v) for v in need_mood.values())
tot_l = sum(len(v) for v in need_look.values())
w(f"**Итого:** {len(no_base)} персонажей без портрета · {tot_m} эмоций · {tot_l} кадров для сценических образов · {len(bg_missing)} фонов отсутствуют совсем · {len(bg_alias_used)} фонов подменены другими.")
w("")

w("## 1. Персонажи без портрета")
w("")
w("Без базового рисунка персонаж в сцене и на столе показывается заглушкой. Это первое, что стоит нарисовать.")
w("")
for pid in no_base:
    scs = used[pid]
    where = short(scs) if scs else "только карточка на столе"
    desc = PEOPLE_NOTES.get(pid) or text(pid)
    moods = sorted(need_mood.get(pid, {}).items())
    w(f"- **{pid}** — {title(pid)}. {desc}".rstrip())
    w(f"  - Сцены: {where}.")
    if moods:
        w("  - Эмоции после портрета: " + ", ".join(f"{f} («{m}»)" for f, (m, _) in moods) + ".")
w("")

w("## 2. Эмоции для персонажей с портретом")
w("")
w("Пока эмоции нет, игра показывает обычный портрет.")
w("")
for pid in sorted(need_mood):
    if pid in no_base:
        continue
    items = sorted(need_mood[pid].items())
    w(f"- **{pid}** — {title(pid)}: " + ", ".join(f"`{f}` («{m}»; {short(s, 3)})" for f, (m, s) in items))
w("")

w("## 3. Сценические образы")
w("")
w("Внутри образа (`@look`) игра ищет эмоцию в папке образа, а если её нет — нейтральный кадр этого же образа. Если нет и его, показывается обычный портрет.")
w("")
for (pid, lk), files in sorted(need_look.items()):
    w(f"- **{pid}** / `{lk}`: " + ", ".join(f"`{f}` ({short(s, 3)})" for f, s in sorted(files.items())))
w("")

w("## 4. Фоны, которых нет совсем")
w("")
w("Здесь сцена показывает пустой фон.")
w("")
if not bg_missing:
    w("Таких нет.")
for b, scs in bg_missing:
    w(f"- **{b}** — {short(scs)}." + (f" {BG_NOTES[b]}" if b in BG_NOTES else ""))
w("")

w("## 5. Фоны, которые сейчас подменены")
w("")
w("Для них в `ui/art.gd` указан похожий существующий фон. Свой PNG с этим именем отключит подмену сам.")
w("")
for b, scs in bg_alias_used:
    note = BG_NOTES.get(b, "")
    w(f"- **{b}** → сейчас `{bg_alias[b]}` — {short(scs, 4)}." + (f" {note}" if note else ""))
w("")

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out))
print(f"no_base={len(no_base)} moods={tot_m} looks={tot_l} bg_missing={len(bg_missing)} bg_alias={len(bg_alias_used)}")
