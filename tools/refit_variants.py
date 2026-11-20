"""Перерисовка вариантов эмоций от базового спрайта: меняется только лицо.

Для каждого варианта, который tools/check_variants.py помечает как «изменено не только лицо»:
1. из базового спрайта вырезается квадрат вокруг лица;
2. Codex (`codex exec`, встроенная генерация картинок) правит в нём выражение,
   ориентируясь на лицо со старого варианта;
3. обратно вклеиваются только изменённые пиксели внутри рамки лица, всё остальное
   остаётся пиксель в пиксель как у базы.

    python tools/refit_variants.py prepare <work>          # задания + рамки лиц
    python tools/refit_variants.py run <work> <job> [...]  # Codex для заданий
    python tools/refit_variants.py apply <work> <job> [...] # вклеить готовое в игру

Исходные файлы перед заменой копируются в output/variant_originals/.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_variants as cv  # noqa: E402

GAME = Path(__file__).resolve().parent.parent
BACKUP = GAME / "output/variant_originals"

# Рамки лиц для баз, у которых нет ни одного «чистого» варианта, по которому их можно найти.
MANUAL_BOXES = {
    "char_charlotte/looks/shrunken_skirt/neutral.png": (415, 330, 645, 540),
    "char_clorinde/looks/fencing/neutral.png": (415, 350, 625, 540),
    "char_clorinde/looks/fencing_button/neutral.png": (415, 350, 625, 540),
    "char_clorinde/looks/training_rest/neutral.png": (395, 230, 600, 460),
    "char_jakob.png": (395, 125, 600, 375),
    "npc_clery.png": (395, 125, 625, 395),
    "npc_cooper_widow.png": (350, 125, 615, 410),
    "npc_delphin.png": (430, 205, 635, 390),
    "npc_farida.png": (440, 190, 670, 400),
    "npc_ferret_merchant.png": (310, 85, 600, 375),
    "npc_foreman.png": (470, 90, 850, 470),
    "npc_isaure.png": (375, 185, 625, 415),
    "npc_jeanne.png": (415, 165, 625, 395),
    "npc_laurent.png": (355, 125, 600, 415),
    "npc_odette.png": (455, 185, 665, 415),
    "npc_pelagie.png": (395, 290, 625, 540),
    "npc_poisson_granny.png": (370, 165, 715, 450),
    "npc_quiet_weaver.png": (435, 125, 665, 375),
    "npc_ribbon_seller.png": (455, 125, 665, 375),
    "npc_shooting_master.png": (370, 80, 655, 370),
    "npc_tenant_boy.png": (370, 305, 695, 595),
}
# У этих вариантов тело не трогали, просто лицо крупное: их не переделываем.
SKIP_BASES = {"duel_thug_big.png"}
# Лицо закрыто фехтовальной маской: выражения не видно, вариант = база.
COPY_BASE = {"char_clorinde/looks/training_mask/smile.png"}

PROMPT = """Use your built-in image generation tool. Edit the attached image base.png (in the current folder) and save the result as out.png in the current folder, exactly the same pixel size as base.png. The second attached image ref.png only shows which facial expression is wanted; do not copy anything else from it.

Edit brief. Use case: identity-preserve. base.png is a production square crop of an original transparent game sprite. Precisely edit only the facial expression (brows, eyelids, eyes, mouth, and if the emotion needs it a light blush or tears) so it reads as "{mood}" and matches the expression on the face in ref.png (the same character; ignore its pose, hands, body, clothes, hair position and framing). Keep the image registration, scale, face landmarks, head angle, palette, line width, hair strands, headwear, accessories and clothing completely fixed. Everything outside the brows, eyes and mouth is copied unchanged and should align with the source at pixel level. Preserve source transparency. Single view, no new objects. Reply only with the saved file name."""


def expand(box, k, size):
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    w, h = max(x1 - x0, 220) * k, max(y1 - y0, 220) * k
    return (max(0, int(cx - w / 2)), max(0, int(cy - h / 2)),
            min(size[0], int(cx + w / 2)), min(size[1], int(cy + h / 2)))


def square(box, size):
    x0, y0, x1, y1 = box
    side = max(512, int(max(x1 - x0, y1 - y0) * 1.9))
    side = min(side, size[0], size[1])
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    sx = min(max(0, cx - side // 2), size[0] - side)
    sy = min(max(0, cy - side // 2), size[1] - side)
    return (sx, sy, sx + side, sy + side)


def job_name(var):
    return var.replace("/", "__").removesuffix(".png")


def prepare(work):
    work.mkdir(parents=True, exist_ok=True)
    good, bad = {}, {}
    for base, var in cv.pairs():
        problem, _ = cv.check(base, var)
        key = base.relative_to(cv.ROOT).as_posix()
        (bad if problem else good).setdefault(key, []).append(var.relative_to(cv.ROOT).as_posix())
    jobs = {}
    for key, variants in bad.items():
        if key in SKIP_BASES:
            continue
        b = Image.open(cv.ROOT / key).convert("RGBA")
        box = MANUAL_BOXES.get(key)
        if box is None:
            rects = []
            for g in good.get(key, []):
                v = Image.open(cv.ROOT / g).convert("RGBA")
                if v.size != b.size:
                    v = v.resize(b.size, Image.LANCZOS)
                bb = ImageChops.difference(b, v).convert("L").point(lambda x: 255 if x > 24 else 0).getbbox()
                if bb:
                    rects.append(bb)
            rects.sort(key=lambda r: (r[2] - r[0]) * (r[3] - r[1]))
            box = rects[len(rects) // 2] if rects else None
        if box is None:
            print("Нет рамки лица:", key)
            continue
        crop = square(expand(box, 1.0, b.size), b.size)
        for var in variants:
            name = job_name(var)
            d = work / name
            d.mkdir(exist_ok=True)
            b.crop(crop).save(d / "base.png")
            v = Image.open(cv.ROOT / var).convert("RGBA")
            ref = Image.new("RGB", v.size, "#808080")
            ref.paste(v, (0, 0), v)
            ref.thumbnail((900, 900))
            ref.save(d / "ref.png")
            mood = Path(var).stem
            (d / "prompt.txt").write_text(PROMPT.format(mood=mood), encoding="utf-8")
            jobs[name] = {"base": key, "variant": var, "box": list(box), "crop": list(crop)}
    (work / "jobs.json").write_text(json.dumps(jobs, ensure_ascii=False, indent=1), encoding="utf-8")
    print("Заданий:", len(jobs))


def run(work, names):
    for name in names:
        d = work / name
        if (d / "out.png").exists():
            continue
        with open(d / "prompt.txt", encoding="utf-8") as prompt, open(d / "codex.log", "w", encoding="utf-8") as log:
            subprocess.run(["codex", "exec", "--skip-git-repo-check", "-s", "workspace-write", "-C", str(d),
                            "-i", "base.png", "-i", "ref.png", "-"],
                           stdin=prompt, stdout=log, stderr=subprocess.STDOUT, cwd=d, timeout=1500)
        print(name, "готово" if (d / "out.png").exists() else "НЕТ out.png", flush=True)


def composite(work, name, info):
    d = work / name
    base = Image.open(cv.ROOT / info["base"]).convert("RGBA")
    crop = tuple(info["crop"])
    side = crop[2] - crop[0]
    src = base.crop(crop)
    out = Image.open(d / "out.png").convert("RGBA")
    if out.size != src.size:
        out = out.resize(src.size, Image.LANCZOS)
    # Маска: только заметно изменённые пиксели, раздутые и смягчённые, и только внутри рамки лица.
    diff = ImageChops.difference(src, out).convert("L").point(lambda x: 255 if x > 18 else 0)
    diff = diff.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(3))
    face = expand(info["box"], 1.25, base.size)
    limit = Image.new("L", src.size, 0)
    limit.paste(255, (face[0] - crop[0], face[1] - crop[1], face[2] - crop[0], face[3] - crop[1]))
    limit = limit.filter(ImageFilter.GaussianBlur(6))
    mask = ImageChops.multiply(diff, limit)
    # Прозрачность не трогаем: силуэт остаётся базовым.
    out.putalpha(src.getchannel("A"))
    patched = Image.composite(out, src, mask)
    result = base.copy()
    result.paste(patched, crop[:2])
    preview = Image.new("RGB", (side * 3, side), "#808080")
    preview.paste(src, (0, 0), src)
    preview.paste(patched, (side, 0), patched)
    preview.paste(Image.new("RGB", src.size, "#ff2040"), (side * 2, 0), mask)
    preview.thumbnail((1200, 400))
    preview.save(d / "preview.jpg", quality=88)
    return result


def apply(work, names):
    jobs = json.loads((work / "jobs.json").read_text(encoding="utf-8"))
    for name in names:
        info = jobs[name]
        target = cv.ROOT / info["variant"]
        if not (work / name / "out.png").exists():
            print("пропуск, нет out.png:", name)
            continue
        backup = BACKUP / info["variant"]
        if target.exists() and not backup.exists():   # новой эмоции бэкап не нужен
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup)
        try:
            composite(work, name, info).save(target)
        except OSError as err:
            # файл может держать открытым редактор или просмотрщик: пропускаем, повторить можно потом
            print("НЕ ЗАПИСАНО:", info["variant"], err)
            continue
        print("вклеено:", info["variant"])


def copy_base():
    for var in COPY_BASE:
        target = cv.ROOT / var
        base = target.parent / "neutral.png"
        backup = BACKUP / var
        if not backup.exists():
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup)
        shutil.copy2(base, target)
        print("копия базы:", var)


if __name__ == "__main__":
    cmd, work = sys.argv[1], Path(sys.argv[2])
    names = sys.argv[3:]
    if cmd == "prepare":
        prepare(work)
    elif cmd == "run":
        run(work, names)
    elif cmd == "apply":
        apply(work, names or json.loads((work / "jobs.json").read_text(encoding="utf-8")).keys())
    elif cmd == "copybase":
        copy_base()
