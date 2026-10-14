#!/usr/bin/env python3
"""Recorta el marco oscuro de una textura opaca y la devuelve a su tamaño. Uso: recortar_borde.py entrada salida [px]"""
import sys

from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
margin = int(sys.argv[3]) if len(sys.argv) > 3 else 10
im = Image.open(src).convert("RGBA")
w, h = im.size
im.crop((margin, margin, w - margin, h - margin)).resize((w, h), Image.LANCZOS).save(dst)
print("%s: recortados %d px por lado" % (dst, margin))
