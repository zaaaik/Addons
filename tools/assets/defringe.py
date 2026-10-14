#!/usr/bin/env python3
"""Quita halos (bordes grises o blancos) de una textura con transparencia.

1. Erosiona el alfa N píxeles (se come el borde contaminado por el fondo).
2. Los píxeles que quedan semitransparentes en el nuevo borde reciben el color de los píxeles opacos
   cercanos (se "sangra" el color hacia fuera), para que al mezclarse con cualquier fondo no tiñan.

Uso: defringe.py entrada salida [--erosion N] [--umbral V]
"""
import sys

from PIL import Image, ImageFilter


def defringe(src, dst, erosion=1, threshold=200):
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    alpha = im.getchannel("A")
    for _ in range(erosion):
        alpha = alpha.filter(ImageFilter.MinFilter(3))
    # Núcleo seguro: píxeles claramente opacos tras la erosión.
    core = alpha.point(lambda v: 255 if v >= threshold else 0)
    px = im.load()
    cp = core.load()
    # Relleno por capas: cada píxel no-núcleo toma el promedio de sus vecinos ya resueltos.
    solved = [[cp[x, y] > 0 for x in range(w)] for y in range(h)]
    color = [[px[x, y][:3] if solved[y][x] else None for x in range(w)] for y in range(h)]
    frontier = True
    for _ in range(max(erosion + 3, 4)):
        if not frontier:
            break
        frontier = False
        updates = []
        for y in range(h):
            for x in range(w):
                if solved[y][x]:
                    continue
                acc, n = [0, 0, 0], 0
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and solved[ny][nx]:
                        c = color[ny][nx]
                        acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]; n += 1
                if n:
                    updates.append((x, y, (acc[0] // n, acc[1] // n, acc[2] // n)))
        for x, y, c in updates:
            solved[y][x] = True
            color[y][x] = c
            frontier = True
    out = Image.new("RGBA", (w, h))
    op = out.load()
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            c = color[y][x] or (0, 0, 0)
            op[x, y] = (c[0], c[1], c[2], ap[x, y])
    out.save(dst)


if __name__ == "__main__":
    a = sys.argv[1:]
    er = int(a[a.index("--erosion") + 1]) if "--erosion" in a else 1
    th = int(a[a.index("--umbral") + 1]) if "--umbral" in a else 200
    defringe(a[0], a[1], er, th)
    print("%s: halo eliminado (erosión %d)" % (a[1], er))
