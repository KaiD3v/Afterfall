"""Checagem de um lote de sprites do Codex antes de entrar no jogo.

Uso: python -I tools/check_sprites.py SHEET.png [SHEET2.png ...] [--max-colors 12]
         [--min-outline 0.95] [--export export.py]
Cada PNG pode ter um JSON ao lado (mesmo nome) no formato Aseprite (frames + frameTags).
Sai com código 1 se algum item der FAIL.
"""
import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image

PALETTE = Path(__file__).resolve().parent.parent / "assets" / "palette" / "paleta_afterfall.gpl"
OUTLINE = (26, 26, 46)
# Desenho por código no exportador: proibido pela regra de arte (só redução e quantização).
DRAWING = re.compile(r"ImageDraw|\.polygon\(|\.rectangle\(|\.ellipse\(|\.line\(|\.arc\(|\.pieslice\(")


def palette():
    lines = PALETTE.read_text().splitlines()
    return {tuple(map(int, l.split()[:3])) for l in lines if l.strip() and l.lstrip()[0].isdigit()}


def frames_of(png, img):
    js = png.with_suffix(".json")
    if not js.exists():
        return [("sheet", (0, 0, img.width, img.height))], {}
    data = json.loads(js.read_text())
    frames = [(f["filename"], tuple(f["frame"][k] for k in ("x", "y", "w", "h"))) for f in data["frames"]]
    tags = {t["name"]: range(t["from"], t["to"] + 1) for t in data["meta"].get("frameTags", [])}
    return frames, tags


def check(png, max_colors, min_outline, pal):
    img = Image.open(png).convert("RGBA")
    px = img.load()
    rows = []
    alphas = {px[x, y][3] for y in range(img.height) for x in range(img.width)}
    rows.append(("transparência só 0 ou 255", alphas <= {0, 255}, f"alfas {sorted(alphas)[:6]}"))
    opaque = {px[x, y][:3] for y in range(img.height) for x in range(img.width) if px[x, y][3] == 255}
    rows.append(("cores dentro da paleta", opaque <= pal, f"{len(opaque - pal)} fora"))

    frames, tags = frames_of(png, img)
    sizes = {(w, h) for _, (_, _, w, h) in frames}
    inside = all(x + w <= img.width and y + h <= img.height for _, (x, y, w, h) in frames)
    rows.append(("frames do mesmo tamanho, dentro da imagem", len(sizes) == 1 and inside, f"{sorted(sizes)}"))

    worst_colors, edge, edge_ok, feet, heights = 0, 0, 0, [], []
    for _, (fx, fy, w, h) in frames:
        solid = {(x, y) for y in range(h) for x in range(w) if px[fx + x, fy + y][3] == 255}
        worst_colors = max(worst_colors, len({px[fx + x, fy + y][:3] for x, y in solid}))
        for x, y in solid:
            if any((x + dx, y + dy) not in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge += 1
                edge_ok += px[fx + x, fy + y][:3] == OUTLINE
        ys = [y for _, y in solid]
        feet.append(max(ys) if ys else None)
        heights.append(max(ys) - min(ys) + 1 if ys else 0)
    rows.append((f"até {max_colors} cores por frame", worst_colors <= max_colors, f"máx {worst_colors}"))
    ratio = edge_ok / edge if edge else 1.0
    rows.append((f"contorno {OUTLINE} em ≥{min_outline:.0%} da borda", ratio >= min_outline, f"{ratio:.1%}"))

    # Dentro de cada animação, o pé não pode pular nem o corpo esticar.
    for name, idx in tags.items():
        if len(idx) < 2:
            continue
        f = [feet[i] for i in idx if feet[i] is not None]
        hs = [heights[i] for i in idx]
        jump, stretch = max(f) - min(f), max(hs) - min(hs)
        rows.append((f"{name}: linha dos pés estável (≤1 px) e altura (≤2 px)", jump <= 1 and stretch <= 2,
                     f"pé varia {jump} px, altura {stretch} px"))
    return rows


def main():
    sys.stdout.reconfigure(encoding="utf-8")  # console do Windows usa cp1252
    ap = argparse.ArgumentParser()
    ap.add_argument("pngs", nargs="+", type=Path)
    ap.add_argument("--max-colors", type=int, default=12)
    ap.add_argument("--min-outline", type=float, default=0.95)
    ap.add_argument("--export", type=Path, action="append", default=[])
    a = ap.parse_args()
    pal = palette()
    failed = False
    for png in a.pngs:
        print(f"\n{png.name}")
        for label, ok, info in check(png, a.max_colors, a.min_outline, pal):
            failed |= not ok
            print(f"  {'PASS' if ok else 'FAIL'}  {label}  ({info})")
    for script in a.export:
        hits = [f"{i}: {l.strip()}" for i, l in enumerate(script.read_text().splitlines(), 1) if DRAWING.search(l)]
        failed |= bool(hits)
        print(f"\n{script.name}\n  {'FAIL' if hits else 'PASS'}  sem desenho por código" + "".join(f"\n    {h}" for h in hits))
    print("\nRESULT:", "FAIL" if failed else "PASS")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
