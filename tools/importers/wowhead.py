"""Importa las misiones de WoW Forever desde Wowhead (https://www.wowhead.com/forever), con permiso de sus autores.

- El listado (por rangos de nivel, para no superar los 1.000 resultados por página) da todos los IDs
  de Forever y si cada misión es nueva o cambió respecto a Classic ("envChange").
- Solo se descargan las páginas de las misiones nuevas, cambiadas o que no estén en AzerothCore.
- Todo se guarda en caché: una página ya descargada no se vuelve a pedir.
- Las peticiones van espaciadas (DELAY segundos) para no cargar el servidor.
"""
import html
import json
import os
import re
import time
import urllib.request

BASE = "https://www.wowhead.com/forever"
USER_AGENT = "MisionesES/0.2 (addon de traducción al español para WoW Forever)"
DELAY = 3.0  # segundos entre peticiones
LEVEL_STEP = 5
MAX_LEVEL = 60

_last_request = [0.0]


def _get(url, cache_path, refresh=False, log=print):
    if not refresh and os.path.exists(cache_path) and os.path.getsize(cache_path) > 0:
        with open(cache_path, encoding="utf-8") as f:
            return f.read()
    wait = DELAY - (time.time() - _last_request[0])
    if wait > 0:
        time.sleep(wait)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                body = r.read().decode("utf-8", errors="replace")
            break
        except Exception as e:  # red inestable o límite de peticiones: reintentar con espera creciente
            if attempt == 3:
                raise
            log("  reintento %s (%s)" % (url, e))
            time.sleep(10 * (attempt + 1))
    _last_request[0] = time.time()
    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    tmp = cache_path + ".part"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(body)
    os.replace(tmp, cache_path)
    return body


def _listview(page):
    """Extrae (datos, truncado) del primer `new Listview({... data: [...]})` de la página."""
    k = page.find("new Listview")
    if k < 0:
        return [], False
    i = page.find("data:[", k) + 5
    depth = 0
    in_str = esc = False
    for j in range(i, len(page)):
        c = page[j]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
            if depth == 0:
                break
    head = page[k:i]
    return json.loads(page[i:j + 1]), "_truncated" in head


def list_quests(cache_dir, refresh=False, log=print):
    """Devuelve {questID: {"name", "level", "status"}} de todas las misiones de Forever en Wowhead."""
    out = {}
    pending = [(lo, min(lo + LEVEL_STEP - 1, MAX_LEVEL)) for lo in range(1, MAX_LEVEL + 1, LEVEL_STEP)]
    pending.insert(0, (0, 0))
    while pending:
        lo, hi = pending.pop(0)
        url = "%s/quests/min-level:%d/max-level:%d" % (BASE, lo, hi)
        page = _get(url, os.path.join(cache_dir, "lists", "%d-%d.html" % (lo, hi)), refresh, log)
        data, truncated = _listview(page)
        if truncated and hi > lo:
            mid = (lo + hi) // 2
            pending[:0] = [(lo, mid), (mid + 1, hi)]
            continue
        if truncated:
            log("  aviso: nivel %d tiene más de 1.000 misiones; se usan las 1.000 primeras" % lo)
        for d in data:
            out[int(d["id"])] = {"name": d.get("name"), "level": d.get("level"),
                                 "status": (d.get("envChange") or {}).get("status")}
    return out


_GENDER = re.compile(r"<([^<>/]{1,40})/([^<>/]{1,40})>")
_PLACEHOLDERS = [(re.compile(r"<name>", re.I), "$N"), (re.compile(r"<class>", re.I), "$C"),
                 (re.compile(r"<race>", re.I), "$R")]


def _to_template(fragment):
    """HTML de Wowhead → plantilla de WoW ($N, $C, $R, $Ga:b;, $B)."""
    if fragment is None:
        return None
    t = re.sub(r"<br\s*/?>", "$B", fragment)
    t = re.sub(r"<script.*?</script>", "", t, flags=re.S)
    t = re.sub(r"<[^>]+>", "", t)
    t = html.unescape(t).replace("\xa0", " ")
    for rx, rep in _PLACEHOLDERS:
        t = rx.sub(rep, t)
    t = _GENDER.sub(lambda m: "$g%s:%s;" % (m.group(1).strip(), m.group(2).strip()), t)
    t = re.sub(r"[ \t]+", " ", t)
    t = re.sub(r"\s*\$B\s*", "$B", t).strip()
    t = re.sub(r"^(\$B)+|(\$B)+$", "", t)
    return t or None


def parse_quest(page):
    """Texto inglés de una página de misión: title, objectives, text, progress, completion."""
    out = {}
    m = re.search(r'<h1 class="heading-size-1">(.*?)</h1>(.*?)(?:<table|<script|<h2|<div)', page, re.S)
    if m:
        out["title"] = _to_template(m.group(1))
        out["objectives"] = _to_template(m.group(2))
    m = re.search(r">Description</h2>(.*?)<h2", page, re.S)
    if m:
        out["text"] = _to_template(m.group(1))
    for key, field in (("progress", "progress"), ("completion", "completion")):
        m = re.search(r'id="[a-z]+-%s"[^>]*>(.*?)</div>' % key, page, re.S)
        if m:
            out[field] = _to_template(m.group(1))
    return {k: v for k, v in out.items() if v}


def load_quests(cache_dir, known_ids=(), refresh_list=False, max_downloads=300, log=print):
    """Lista Forever y lee las misiones nuevas, cambiadas o desconocidas.

    Las páginas en caché se leen siempre; como mucho se descargan `max_downloads` páginas nuevas por
    ejecución, para avanzar poco a poco. Devuelve (ids_de_forever, {questID: {campos EN}}, pendientes).
    """
    listing = list_quests(cache_dir, refresh_list, log)
    known = set(known_ids)
    wanted = sorted(q for q, info in listing.items()
                    if info["status"] in ("new", "updated") or q not in known)
    quests, downloads, pending = {}, 0, 0
    for qid in wanted:
        path = os.path.join(cache_dir, "quests", "%d.html" % qid)
        if not os.path.exists(path):
            if downloads >= max_downloads:
                pending += 1
                continue
            downloads += 1
            if downloads % 50 == 0:
                log("  descargadas %d/%d" % (downloads, max_downloads))
        page = _get("%s/quest=%d" % (BASE, qid), path, log=log)
        parsed = parse_quest(page)
        if parsed.get("title"):
            quests[qid] = parsed
    log("Wowhead: %d misiones en Forever; %d leídas (%d descargadas ahora), %d pendientes para la próxima vez"
        % (len(listing), len(quests), downloads, pending))
    return set(listing), quests, pending
