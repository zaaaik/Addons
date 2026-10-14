#!/usr/bin/env python3
"""Suaviza una textura de fondo para que el texto se lea bien encima.

Uso: aclarar.py entrada salida [mezcla] [contraste]
- mezcla: cuánto se acerca a un pergamino liso (#EEDAAC); 0 = nada, 1 = liso.
- contraste: factor de contraste de las manchas (1 = igual, 0.5 = la mitad).
"""
import sys

from PIL import Image, ImageEnhance

src, dst = sys.argv[1], sys.argv[2]
mix = float(sys.argv[3]) if len(sys.argv) > 3 else 0.35
contrast = float(sys.argv[4]) if len(sys.argv) > 4 else 0.6
im = Image.open(src).convert("RGBA")
alpha = im.getchannel("A")
rgb = ImageEnhance.Contrast(im.convert("RGB")).enhance(contrast)
flat = Image.new("RGB", rgb.size, (238, 218, 172))   # pergamino cálido liso
out = ImageEnhance.Color(Image.blend(rgb, flat, mix)).enhance(1.15)  # recupera la calidez
out.putalpha(alpha)
out.save(dst)
print("%s: mezcla %.2f, contraste %.2f" % (dst, mix, contrast))
