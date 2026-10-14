"""Prepara textos para la IA y los recompone después.

- Divide en párrafos por $B y saltos de línea (se traducen por separado y se vuelven a unir igual).
- Sustituye tokens ($N, $C, $R...) y nombres propios por marcadores ZQX<n>ZQ que la IA no toca.
- Los tokens de género $Gél:ella; se traducen como dos frases sueltas y se reconstruyen.
"""
import re

SPLIT = re.compile(r"((?:\$[Bb]|\n)+)")
TOKEN = re.compile(r"\$[NnCcRr]")
GENDER = re.compile(r"\$[Gg]\s*([^:;]*?)\s*:\s*([^;]*?)\s*;")
MARK = "ZQX%dZQ"
MARK_RX = re.compile(r"ZQX\s*(\d+)\s*ZQ", re.I)

# Palabras que empiezan en mayúscula a mitad de frase pero no son nombres propios.
_NOT_NAMES = {"I", "I'm", "I've", "I'll", "I'd", "Mr", "Mrs", "Sir", "Lady", "Lord", "King", "Queen",
              "Prince", "Princess", "Captain", "General", "Brother", "Sister", "Father", "Mother",
              "Light", "Horde", "Alliance"}
_NAME_SEQ = re.compile(r"(?<![.!?]\s)(?<!^)(?<![\"'])\b([A-Z][a-z'\-]+(?:\s+(?:of|the|de)?\s*[A-Z][a-z'\-]+)*)")


def find_names(text, known=(), heuristic=True):
    """Nombres propios a conservar en inglés: lista conocida + heurística de mayúsculas a mitad de frase."""
    names = {n for n in known if n and n in text}
    for m in (_NAME_SEQ.finditer(text) if heuristic else ()):
        n = m.group(1).strip()
        if n.split()[0] not in _NOT_NAMES and len(n) > 2:
            names.add(n)
    return sorted(names, key=len, reverse=True)


class Job:
    """Un texto descompuesto en piezas traducibles."""

    def __init__(self, text, known_names=(), heuristic=True):
        self.heuristic = heuristic
        self.parts = []      # lista de ("sep", s) o ("seg", índice en self.segments)
        self.segments = []   # textos enmascarados a traducir
        self.masks = []      # por segmento: {n: original}
        self.genders = []    # por segmento: {n: (índice masc, índice fem)} en extra
        self.extra = []      # frases sueltas de los tokens de género
        for piece in SPLIT.split(text):
            if not piece:
                continue
            if SPLIT.fullmatch(piece):
                self.parts.append(("sep", piece))
            elif piece.strip():
                self.parts.append(("seg", len(self.segments)))
                self._add_segment(piece, known_names)
            else:
                self.parts.append(("sep", piece))

    def _add_segment(self, seg, known_names):
        masks, genders = {}, {}

        def mark(original):
            n = len(masks)
            masks[n] = original
            return MARK % n

        def gender(m):
            n = len(masks)
            masks[n] = None
            genders[n] = (len(self.extra), len(self.extra) + 1)
            self.extra += [m.group(1), m.group(2)]
            return MARK % n

        if not self.heuristic:
            # Títulos: "Silver of the Waves" → "Silver of the waves"; Argos traduce mejor en minúscula.
            seg = seg[:1] + " ".join(w if w in known_names else w.lower() for w in seg[1:].split(" "))
        seg = GENDER.sub(gender, seg)
        seg = TOKEN.sub(lambda m: mark(m.group(0)), seg)
        for name in find_names(seg, known_names, self.heuristic):
            seg = re.sub(r"(?<![A-Za-z])%s(?![A-Za-z])" % re.escape(name), lambda m: mark(name), seg)
        self.segments.append(seg)
        self.masks.append(masks)
        self.genders.append(genders)

    def texts(self):
        return self.segments + self.extra

    def rebuild(self, translated):
        """Recompone el texto traducido. Devuelve None si la IA perdió algún marcador."""
        segs, extra = translated[:len(self.segments)], translated[len(self.segments):]
        out_segs = []
        for i, t in enumerate(segs):
            found = [int(x) for x in MARK_RX.findall(t)]
            if sorted(found) != sorted(self.masks[i]):
                return None

            def restore(m, i=i):
                n = int(m.group(1))
                if n in self.genders[i]:
                    a, b = self.genders[i][n]
                    return "$g%s:%s;" % (_same_case(self.extra[a], extra[a]), _same_case(self.extra[b], extra[b]))
                return self.masks[i][n]

            out_segs.append(MARK_RX.sub(restore, t).strip())
        return "".join(p[1] if p[0] == "sep" else out_segs[p[1]] for p in self.parts)


def _same_case(original, translated):
    """La IA suele capitalizar palabras sueltas; se respeta la mayúscula inicial del original."""
    t = translated.strip().rstrip(".")
    if original[:1].islower() and t[:1].isupper():
        t = t[:1].lower() + t[1:]
    return t


# Groserías que una IA puede colar por error ("Bloodfury Trinkets" → "Trinkets de mierda").
_PROFANITY = re.compile(r"\b(mierda|puta|puto|joder|jodid[oa]s?|coño|cabr[oó]n|pendej[oa]|culo|polla|verga|chingad[oa])\b",
                        re.I)
_PROFANITY_EN = re.compile(r"\b(shit|fuck|bitch|bastard|ass|damn)", re.I)


def is_clean(en, es):
    """False si la traducción trae groserías que no están en el texto inglés."""
    return not (_PROFANITY.search(es) and not _PROFANITY_EN.search(en))


_NEUTRAL = [(re.compile(r"\bvosotr([oa])s\b"), "ustedes"), (re.compile(r"\bVosotr([oa])s\b"), "Ustedes")]


def neutral_spanish(text):
    """Ajustes mínimos hacia el español neutro."""
    for rx, rep in _NEUTRAL:
        text = rx.sub(rep, text)
    return text


def translate_all(engine, texts, known_names=(), batch=64, titles=()):
    """Traduce una lista de textos protegiendo tokens y nombres. Devuelve lista (None = falló).

    `titles`: índices de textos en formato título (Todas Las Palabras En Mayúscula), donde la
    heurística de nombres propios no sirve y solo se protegen los nombres conocidos.
    """
    titles = set(titles)
    jobs = [Job(t, known_names, i not in titles) for i, t in enumerate(texts)]
    flat, owners = [], []
    for j_index, job in enumerate(jobs):
        for t in job.texts():
            flat.append(t)
            owners.append(j_index)
    results = []
    for i in range(0, len(flat), batch):
        results += engine.translate(flat[i:i + batch])
    out, pos = [], 0
    for text, job in zip(texts, jobs):
        n = len(job.texts())
        rebuilt = job.rebuild(results[pos:pos + n])
        pos += n
        if rebuilt is not None and not job.heuristic:
            rebuilt = rebuilt[:1].upper() + rebuilt[1:]
        if rebuilt is not None and not is_clean(text, rebuilt):
            rebuilt = None
        out.append(neutral_spanish(rebuilt) if rebuilt is not None else None)
    return out
