#!/usr/bin/env python3
"""Quita el fondo oscuro sobrante de los assets y los convierte a TGA de 32 bits para WoW.

Uso: python3 tools/assets/limpiar_fondo.py entrada.png salida.tga [--solo-oscuro] [--hueco x0,y0,x1,y1]
Se vuelven transparentes los píxeles oscuros y poco saturados conectados con el borde de la imagen
(relleno por inundación desde los bordes), y se suaviza el contorno para evitar halos.
"""
import sys
from collections import deque

from PIL import Image, ImageFilter


def is_background(px, threshold, light):
    """Fondo = oscuro y gris, o (si light) claro y gris como la cuadrícula de transparencia dibujada."""
    r, g, b, a = px
    if a < 20:
        return True
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    sat = max(r, g, b) - min(r, g, b)
    return sat < 28 and (lum < threshold or (light and lum > 170))


def clean(src, dst, threshold=60, light=True, hole=None):
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    px = im.load()
    bg = [[False] * w for _ in range(h)]
    q = deque((x, y) for x in range(w) for y in (0, h - 1))
    q.extend((x, y) for y in range(h) for x in (0, w - 1))
    while q:
        x, y = q.popleft()
        if bg[y][x] or not is_background(px[x, y], threshold, light):
            continue
        bg[y][x] = True
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx]:
                q.append((nx, ny))
    if hole:
        # Hueco central que debe quedar transparente (p. ej. el marco de recompensa).
        x0, y0, x1, y1 = hole
        for y in range(y0, y1):
            for x in range(x0, x1):
                bg[y][x] = True
    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            if bg[y][x]:
                ap[x, y] = 0
    # Contorno suave: un desenfoque leve del alfa evita el borde dentado.
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))
    orig_alpha = im.getchannel("A")
    alpha = Image.composite(alpha, Image.new("L", (w, h), 0), orig_alpha.point(lambda v: 255 if v > 0 else 0))
    im.putalpha(alpha)
    im.save(dst)
    removed = sum(1 for row in bg for v in row if v)
    return removed, w * h


if __name__ == "__main__":
    args = sys.argv[1:]
    light = "--solo-oscuro" not in args
    hole = None
    if "--hueco" in args:
        hole = tuple(int(v) for v in args[args.index("--hueco") + 1].split(","))
    removed, total = clean(args[0], args[1], light=light, hole=hole)
    print("%s: %d de %d píxeles de fondo eliminados" % (args[1], removed, total))
