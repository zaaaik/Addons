"""Normalización y hash de textos. Debe comportarse EXACTAMENTE igual que MES.Key en Core.lua.

El juego entrega el texto ya resuelto ("Hello, Arthas the warrior") y la base de datos lo tiene como
plantilla ("Hello, $N the $c"). Ambos se llevan a la misma forma ("hello, $n the $c") antes de hashear:
  - Lua sustituye el nombre, la clase y la raza del jugador por $n/$c/$r.
  - Python sustituye los tokens de la plantilla por $n/$c/$r y expande $G (masculino/femenino).
Después: espacios colapsados, sin espacios en los extremos y minúsculas ASCII (como string.lower de Lua).
"""
import re

_WS = re.compile(r"[ \t\n\v\f\r]+")
_GENDER = re.compile(r"\$[Gg]\s*([^:;]*?)\s*:\s*([^;]*?)\s*;")
_TOKENS = [(re.compile(r"\$[Nn]"), "$n"), (re.compile(r"\$[Cc]"), "$c"), (re.compile(r"\$[Rr]"), "$r"),
           (re.compile(r"\$[Bb]"), " ")]
_ASCII_LOWER = str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")


def hash32(text):
    """djb2 de 32 bits sobre los bytes UTF-8, en hexadecimal (igual que MES.Hash)."""
    h = 5381
    for b in text.encode("utf-8"):
        h = (h * 33 + b) % 4294967296
    return "%08x" % h


def finish(text):
    return _WS.sub(" ", text).strip(" \t\n\v\f\r").translate(_ASCII_LOWER)


def gender_variants(template):
    """Devuelve [masculino, femenino] si hay tokens $G, o [plantilla] si no."""
    if not _GENDER.search(template):
        return [template]
    return [_GENDER.sub(lambda m: m.group(1), template), _GENDER.sub(lambda m: m.group(2), template)]


def template_forms(template):
    """Formas normalizadas de una plantilla de la base de datos (una por variante de género)."""
    out = []
    for v in gender_variants(template or ""):
        for rx, rep in _TOKENS:
            v = rx.sub(rep, v)
        v = finish(v)
        if v not in out:
            out.append(v)
    return out


def template_hashes(template):
    return [hash32(f) for f in template_forms(template)]


def strip_player_name(text, name):
    """Lo que hace el recolector antes de guardar: el nombre del jugador pasa a ser $N."""
    if name:
        text = text.replace(name, "$N")
    return text.strip()
