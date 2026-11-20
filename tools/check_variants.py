"""Проверка вариантов эмоций: меняется ли только лицо.

Каждый <id>/<mood>.png сравнивается со своим базовым спрайтом (<id>.png,
для одежды — looks/<look>/neutral.png). Вариант считается плохим, если
у него другой размер, сдвинулся силуэт (альфа-канал) или изменилась
слишком большая область.

    python tools/check_variants.py            # список проблем
    python tools/check_variants.py --sheet out # плюс листы «база | вариант | разница»
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent / "fleur/assets/art/characters"
PIXEL = 24          # порог изменения цвета пикселя
ALPHA_PX = 1500     # сколько пикселей силуэта может поменяться (пряди у лица, сглаживание)
AREA = 0.12         # доля спрайта, которую может занимать область изменений


def pairs():
    for base in sorted(ROOT.glob("*.png")):
        folder = ROOT / base.stem
        if folder.is_dir():
            for v in sorted(folder.glob("*.png")):
                yield base, v
            for look in sorted((folder / "looks").glob("*")):
                lb = look / "neutral.png"
                if lb.exists():
                    for v in sorted(look.glob("*.png")):
                        if v != lb:
                            yield lb, v


def check(base_path, var_path):
    b = Image.open(base_path).convert("RGBA")
    v = Image.open(var_path).convert("RGBA")
    note = ""
    if b.size != v.size:
        # Тот же рисунок в другом разрешении (или на пиксель выше) сравниваем после
        # приведения к размеру базы; другая пропорция — уже другая картинка.
        if abs(v.size[0] / v.size[1] - b.size[0] / b.size[1]) > 0.01:
            return f"другая пропорция: {v.size} при базе {b.size}", None
        v = v.resize(b.size, Image.LANCZOS)
        note = f" [масштаб {v.size}]"
    alpha = ImageChops.difference(b.getchannel("A"), v.getchannel("A")).point(lambda x: 255 if x > 64 else 0)
    alpha_px = alpha.histogram()[255]
    diff = ImageChops.difference(b, v).convert("L").point(lambda x: 255 if x > PIXEL else 0)
    box = diff.getbbox()
    area = 0 if box is None else (box[2] - box[0]) * (box[3] - box[1]) / (b.size[0] * b.size[1])
    problems = []
    if alpha_px > ALPHA_PX:
        problems.append(f"силуэт: {alpha_px} px")
    if area > AREA:
        problems.append(f"изменено {area:.0%} площади {box}")
    return ", ".join(problems) + (note if problems else ""), (b, v, diff)


def sheet(out_dir, name, b, v, diff):
    w, h = b.size
    s = Image.new("RGB", (w * 3, h), "#808080")
    s.paste(b, (0, 0), b)
    s.paste(v, (w, 0), v)
    red = Image.new("RGB", (w, h), "#ff2040")
    s.paste(red, (w * 2, 0), diff)
    s.thumbnail((1500, 700))
    s.save(out_dir / (name.replace("/", "__") + ".jpg"), quality=85)


def main():
    out = None
    if "--sheet" in sys.argv:
        out = Path(sys.argv[sys.argv.index("--sheet") + 1])
        out.mkdir(parents=True, exist_ok=True)
    bad = total = 0
    for base, var in pairs():
        total += 1
        problem, imgs = check(base, var)
        if problem:
            bad += 1
            name = var.relative_to(ROOT).as_posix()
            print(f"{name}: {problem}")
            if out and imgs:
                sheet(out, name, *imgs)
    print(f"Проверено вариантов: {total}, с изменениями вне лица: {bad}")


if __name__ == "__main__":
    main()
