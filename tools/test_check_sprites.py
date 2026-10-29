"""Autoteste do check_sprites: pé estável passa, pé que pula 3 px falha; tile sem costura passa,
tile com faixa escura na borda falha.
Rodar: python -I tools/test_check_sprites.py
"""
import json
import sys
import tempfile
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_sprites as cs

OUT, BODY = (26, 26, 46), (52, 73, 94)


def sheet(folder, name, foot_offsets):
    img = Image.new("RGBA", (16 * len(foot_offsets), 16), (0, 0, 0, 0))
    for i, off in enumerate(foot_offsets):
        for y in range(4 + off, 12 + off):
            for x in range(4, 10):
                edge = x in (4, 9) or y in (4 + off, 11 + off)
                img.putpixel((16 * i + x, y), (*(OUT if edge else BODY), 255))
    png = Path(folder) / f"{name}.png"
    img.save(png)
    png.with_suffix(".json").write_text(json.dumps({
        "frames": [{"filename": f"f{i}", "frame": {"x": 16 * i, "y": 0, "w": 16, "h": 16}, "duration": 120}
                   for i in range(len(foot_offsets))],
        "meta": {"frameTags": [{"name": "walk_down", "from": 0, "to": len(foot_offsets) - 1}]}}))
    return png


def feet_ok(png):
    rows = cs.check(png, 12, 0.95, cs.palette())
    return [ok for label, ok, _ in rows if "pés" in label][0], all(ok for _, ok, _ in rows)


with tempfile.TemporaryDirectory() as d:
    assert feet_ok(sheet(d, "estavel", [0, 0, 1, 0])) == (True, True)
    assert feet_ok(sheet(d, "pula", [0, 3, 0, 0])) == (False, False)


def tiles(folder, band):
    """Dois tiles 8x8 de ruído leve; com band, o segundo ganha uma coluna escura na borda direita."""
    a, b = (74, 74, 82), (110, 110, 118)
    img = Image.new("RGBA", (16, 8), (0, 0, 0, 255))
    for t in (0, 1):
        for y in range(8):
            for x in range(8):
                c = b if band and t == 1 and x == 7 else (a if (x + y) % 3 else (43, 43, 51))
                img.putpixel((8 * t + x, y), (*c, 255))
    png = Path(folder) / f"tiles{int(band)}.png"
    img.save(png)
    png.with_suffix(".json").write_text(json.dumps({
        "frames": [{"filename": n, "frame": {"x": 8 * i, "y": 0, "w": 8, "h": 8}} for i, n in enumerate(("a", "b"))],
        "meta": {"seamless": [["a", "b"]]}}))
    return all(ok for _, ok, _ in cs.check(png, 6, 0.95, cs.palette(), tiles=True))


with tempfile.TemporaryDirectory() as d:
    assert tiles(d, False)
    assert not tiles(d, True)
print("check_sprites: PASS")
