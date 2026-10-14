#!/usr/bin/env python3
"""Genera una maqueta aproximada del panel de pergamino con las texturas reales (docs/maquetas/)."""
from PIL import Image, ImageDraw, ImageFont

T = 'MisionesES/Textures/'
W, H, S = 260, 420, 2
PAD, TOP, EDGE, OUT = 28, 18, 40, 6
canvas = Image.new('RGBA', ((W + 80) * S, (H + 100) * S), (88, 58, 30, 255))
ox, oy = 40 * S, 50 * S


def tex(n):
    return Image.open(T + n + '.tga').convert('RGBA')


canvas.alpha_composite(tex('parchment_old').resize(((W - 8) * S, (H - 8) * S)), (ox + 4 * S, oy + 4 * S))
e, c = tex('parchment_edges'), 64


def crop(box, w, h):
    return e.crop(box).resize((max(1, w), max(1, h)))


E, o = EDGE * S, OUT * S
L, Tp, R, B = ox - o, oy - o, ox + W * S + o, oy + H * S + o
for box, pos in (((0, 0, c, c), (L, Tp)), ((256 - c, 0, 256, c), (R - E, Tp)),
                 ((0, 256 - c, c, 256), (L, B - E)), ((256 - c, 256 - c, 256, 256), (R - E, B - E))):
    canvas.alpha_composite(crop(box, E, E), pos)
canvas.alpha_composite(crop((c, 0, 256 - c, c), R - L - 2 * E, E), (L + E, Tp))
canvas.alpha_composite(crop((c, 256 - c, 256 - c, 256), R - L - 2 * E, E), (L + E, B - E))
canvas.alpha_composite(crop((0, c, c, 256 - c), E, B - Tp - 2 * E), (L, Tp + E))
canvas.alpha_composite(crop((256 - c, c, 256, 256 - c), E, B - Tp - 2 * E), (R - E, Tp + E))
RH = int((W + 44) * 128 / 512)            # alto del rollo (la textura es 512x128)
OFF = int(12 + RH * (1 - 0.523) / 2)      # se hunde 12 px en la hoja
OFF_B = int(12 + RH * (1 - 0.500) / 2)
canvas.alpha_composite(tex('scroll_top').resize(((W + 44) * S, RH * S)), (ox - 22 * S, oy + OFF * S - RH * S))
canvas.alpha_composite(tex('scroll_bottom').resize(((W + 44) * S, RH * S)), (ox - 22 * S, oy + H * S - OFF_B * S))

d = ImageDraw.Draw(canvas)
title = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf', 17 * S)
body = ImageFont.truetype('/usr/share/fonts/truetype/freefont/FreeSerif.ttf', 14 * S)
INK, BLACK = (46, 31, 15), (0, 0, 0)
x, y, width = ox + PAD * S, oy + (PAD + TOP) * S, (W - 2 * PAD - 22) * S
clip = oy + (H - PAD - TOP) * S


def wrap(text, font):
    lines, cur = [], ''
    for w in text.split():
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=font) > width:
            lines.append(cur)
            cur = w
        else:
            cur = t
    return lines + [cur]


def para(text, font=body, fill=INK, step=17, gap=8):
    global y
    for ln in wrap(text, font):
        if y + 16 * S > clip:
            return
        d.text((x, y), ln, font=font, fill=fill)
        y += step * S
    y += gap * S


d.text((x, y), 'Los tubérculos hojazul', font=title, fill=BLACK)
y += 26 * S
canvas.alpha_composite(tex('divider_ink').resize((width - 16 * S, 16 * S)), (x + 8 * S, y))
y += 22 * S
para('Los tubérculos hojazul son muy apreciados en todo el mundo. Pero son muy raros. Solo se encuentran aquí, en Los Baldíos, enterrados profundamente en Horado Rajacieno.')
para('¡Y es imposible encontrarlos a no ser que sepas dónde mirar! Por eso he amaestrado husmeadores taltuza para que los busquen.')
para('No será fácil, pero si me traes tubérculos te pagaré muy bien.')
d.text((x, y), 'Objetivos', font=title, fill=BLACK)
y += 24 * S
para('Coge un cajón con agujeros. Coge una vara de mando de husmeador. Lee el manual de propietario de husmeador. '
     'Cuando llegues a Horado Rajacieno, usa la vara de mando con el husmeador.', gap=0)

# Flecha "hay más texto": siempre a 4/5 de la altura del área de texto, pegada a la derecha.
top, right = oy + (PAD + TOP) * S, ox + (W - PAD + 6) * S
visible = clip - top
arrow = tex('arrow_down').resize((30 * S, 30 * S))
cx, cy = right - 8 * S, top + int(visible * 0.8)
canvas.alpha_composite(arrow, (cx - 15 * S, cy - 15 * S))
canvas.convert('RGB').save('docs/maquetas/panel_registro.png')
