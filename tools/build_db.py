#!/usr/bin/env python3
"""Genera la base de datos de MisionesES.

Pasos: importar AzerothCore (EN + español oficial) → filtrar IDs de Forever → detectar españoles
sospechosos → fusionar capturas del juego → traducir con IA solo lo que falte → aplicar revisiones
manuales → escribir data/*.json y MisionesES/Data/*.lua.

Uso:
  python3 tools/build_db.py                    # importa + traduce con Argos
  python3 tools/build_db.py --engine none      # sin IA (solo español oficial)
  python3 tools/build_db.py --engine ollama --model qwen2.5:7b
  python3 tools/build_db.py --limit 20         # traduce como mucho 20 textos (pruebas)
"""
import argparse
import datetime
import glob
import json
import os
import re
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)

import luatable  # noqa: E402
import normalize as nz  # noqa: E402
import protect  # noqa: E402
from engines import get_engine  # noqa: E402
from importers import azerothcore  # noqa: E402
from importers import wowhead  # noqa: E402

FIELDS = ("title", "text", "objectives", "progress", "completion")
SHORT = {"title": "t", "text": "d", "objectives": "o", "progress": "p", "completion": "c"}
DEFAULT_MAX_ID = 9000
# Misiones de relleno o eliminadas que AzerothCore conserva ("<NYI>", "<TXT>", "[UNUSED]"...).
PLACEHOLDER = re.compile(r"^\s*[<\[]|UNUSED|DEPRECATED|\[PH\]|^zz", re.I)
# Términos que delatan un español de una expansión posterior al texto inglés.
LATER_TERMS = ("Alamuerte", "Cataclismo", "Crepúsculo", "Garrosh", "Pandaria", "Draenor", "Rasganorte")
LATER_TERMS_EN = ("Deathwing", "Cataclysm", "Twilight", "Garrosh", "Pandaria", "Draenor", "Northrend")


def field_hash(text):
    return nz.hash32(nz.finish(text or ""))


def suspicious(en, es):
    """True si el español oficial probablemente no corresponde al texto inglés."""
    if not en or not es:
        return False
    if len(en) > 40:
        ratio = len(es) / len(en)
        if ratio < 0.6 or ratio > 1.8:
            return True
    for term_es, term_en in zip(LATER_TERMS, LATER_TERMS_EN):
        if term_es in es and term_en not in en:
            return True
    return False


def read_json(path, default):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return default


def write_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")


def load_captures(paths):
    """Fusiona varios SavedVariables de MisionesES_Captura."""
    quests, gossip, ids = {}, {}, set()
    for path in paths:
        cap = luatable.load_savedvariables(path).get("MisionesES_Captura") or {}
        for qid, q in (cap.get("quests") or {}).items():
            entry = quests.setdefault(int(qid), {})
            for f in FIELDS:
                if isinstance(q.get(f), str) and q[f].strip():
                    entry[f] = q[f].strip()
        for _, text in (cap.get("gossip") or {}).items():
            if isinstance(text, str) and text.strip():
                gossip[nz.template_hashes(text)[0]] = text.strip()
        ids.update(int(i) for i in (cap.get("ids") or {}))
    return quests, gossip, ids


def merge_quests(ac, captured, previous, revisions, allowed):
    """Decide para cada campo el texto ES y su origen. Devuelve (quests, pendientes)."""
    out, pending = {}, []
    for qid in sorted(set(ac) | set(captured)):
        if qid not in allowed and qid not in captured:
            continue
        base = ac.get(qid, {"en": {}, "es": {}})
        prev = previous.get(str(qid), {})
        rev = revisions.get(str(qid), {})
        en = dict(base["en"])
        en.update(captured.get(qid, {}))
        if not en.get("title") and not en.get("text"):
            continue
        if qid not in captured and PLACEHOLDER.search(en.get("title") or ""):
            continue
        entry = {"en": en, "es": {}, "src": {}, "en_h": {}, "descartado": {}}
        for f in FIELDS:
            if not en.get(f):
                continue
            h = field_hash(en[f])
            entry["en_h"][f] = h
            official = base["es"].get(f)
            ac_en = base["en"].get(f)
            same_en = ac_en == en[f] or (ac_en and set(nz.template_hashes(ac_en)) & set(nz.template_hashes(en[f])))
            if f in rev:
                entry["es"][f], entry["src"][f] = rev[f], "revisado"
            elif official and same_en and not suspicious(en[f], official):
                entry["es"][f], entry["src"][f] = official, "oficial"
            elif prev.get("src", {}).get(f) == "ia" and prev.get("en_h", {}).get(f) == h:
                entry["es"][f], entry["src"][f] = prev["es"][f], "ia"
            else:
                pending.append((qid, f))
            if official and entry["src"].get(f) != "oficial":
                entry["descartado"][f] = official
        if not entry["descartado"]:
            del entry["descartado"]
        out[str(qid)] = entry
    return out, pending


def merge_gossip(ac_pairs, captured, previous, revisions):
    out, pending = {}, []
    sources = [(en, es) for en, es in ac_pairs] + [(en, None) for en in captured.values()]
    for en, official in sources:
        key = nz.template_hashes(en)[0]
        if key in out:
            continue
        h = field_hash(en)
        prev = previous.get(key, {})
        entry = {"en": en, "en_h": h}
        if key in revisions:
            entry.update(es=revisions[key], src="revisado")
        elif official:
            entry.update(es=official, src="oficial")
        elif prev.get("src") == "ia" and prev.get("en_h") == h:
            entry.update(es=prev["es"], src="ia")
        else:
            pending.append(key)
        out[key] = entry
    return out, pending


def translate_pending(engine, quests, q_pending, gossip, g_pending, names, limit, log):
    jobs = [("q", qid, f, quests[str(qid)]["en"][f]) for qid, f in q_pending]
    jobs += [("g", key, None, gossip[key]["en"]) for key in g_pending]
    if limit is not None:
        jobs = jobs[:limit]
    if not jobs:
        return 0, 0
    log("Traduciendo %d textos con %s..." % (len(jobs), engine.name))
    ok = failed = 0
    chunk = 200
    for i in range(0, len(jobs), chunk):
        part = jobs[i:i + chunk]
        results = protect.translate_all(engine, [j[3] for j in part], names)
        for (kind, key, f, _), es in zip(part, results):
            if not es:
                failed += 1
                continue
            ok += 1
            if kind == "q":
                quests[str(key)]["es"][f] = es
                quests[str(key)]["src"][f] = "ia"
            else:
                gossip[key].update(es=es, src="ia")
        log("  %d/%d" % (min(i + chunk, len(jobs)), len(jobs)))
    return ok, failed


def write_lua(path, header, var, lines, chunk=400):
    with open(path, "w", encoding="utf-8") as f:
        f.write(header)
        for i in range(0, len(lines), chunk):
            # Cada bloque va en su propia función para no superar los límites de constantes de Lua.
            f.write("do local function load(%s)\n" % var)
            f.write("\n".join(lines[i:i + chunk]))
            f.write("\nend load(%s) end\n" % var)


def generate_lua(quests, gossip, meta, addon_dir):
    data_dir = os.path.join(addon_dir, "Data")
    q_lines = []
    for qid in sorted(quests, key=int):
        e = quests[qid]
        if not e["es"]:
            continue
        row = {SHORT[f]: e["es"][f] for f in FIELDS if f in e["es"]}
        en = e["en"]
        row["h"] = "|".join(nz.template_hashes((en.get("title") or "") + " " + (en.get("text") or "")))
        if "ia" in e["src"].values():
            row["ia"] = 1
        q_lines.append("Q[%s]=%s" % (qid, luatable.lua_value(row)))
    g_lines = []
    seen = set()
    for key in sorted(gossip):
        e = gossip[key]
        if not e.get("es"):
            continue
        value = e["es"] if e["src"] != "ia" else {"x": e["es"], "ia": 1}
        for h in nz.template_hashes(e["en"]):
            if h not in seen:
                seen.add(h)
                g_lines.append("G[%s]=%s" % (luatable.lua_string(h), luatable.lua_value(value)))
    head = "-- Generado por tools/build_db.py. No editar a mano.\nlocal _, MES = ...\n"
    write_lua(os.path.join(data_dir, "Quests.lua"), head + "local Q = MES.DB.quests\n", "Q", q_lines)
    write_lua(os.path.join(data_dir, "Gossip.lua"), head + "local G = MES.DB.gossip\n", "G", g_lines)
    with open(os.path.join(data_dir, "Meta.lua"), "w", encoding="utf-8") as f:
        f.write(head + "MES.DB.meta = %s\n" % luatable.lua_value(meta))
    return len(q_lines), len(g_lines)


def report(quests, gossip):
    counts = {}
    for e in quests.values():
        for f, s in e["src"].items():
            counts.setdefault(f, {}).setdefault(s, 0)
            counts[f][s] += 1
    g = {}
    for e in gossip.values():
        g[e.get("src", "pendiente")] = g.get(e.get("src", "pendiente"), 0) + 1
    lines = ["Misiones: %d" % len(quests)]
    for f in FIELDS:
        c = counts.get(f, {})
        total = sum(1 for e in quests.values() if f in e["en"])
        lines.append("  %-11s oficial %5d | ia %5d | revisado %3d | pendiente %5d" % (
            f, c.get("oficial", 0), c.get("ia", 0), c.get("revisado", 0), total - sum(c.values())))
    lines.append("Diálogos: %d (oficial %d, ia %d, revisado %d, pendiente %d)" % (
        len(gossip), g.get("oficial", 0), g.get("ia", 0), g.get("revisado", 0), g.get("pendiente", 0)))
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--engine", default="argos", choices=["argos", "ollama", "fake", "none"])
    ap.add_argument("--model", default="qwen2.5:7b", help="modelo de Ollama")
    ap.add_argument("--limit", type=int, default=None, help="máximo de textos a traducir")
    ap.add_argument("--data", default=os.path.join(ROOT, "data"))
    ap.add_argument("--addon", default=os.path.join(ROOT, "MisionesES"))
    ap.add_argument("--capturas", default=os.path.join(ROOT, "capturas"))
    ap.add_argument("--cache", default=os.path.join(ROOT, "data", ".cache", "azerothcore"))
    ap.add_argument("--ac-folder", default=None, help="carpeta con el SQL ya descargado (tests)")
    ap.add_argument("--wowhead", action="store_true", help="importar misiones de Forever desde Wowhead")
    ap.add_argument("--wowhead-max", type=int, default=300, help="máximo de páginas nuevas a descargar por ejecución")
    ap.add_argument("--wowhead-refresh-list", action="store_true", help="volver a descargar el listado de misiones")
    args = ap.parse_args(argv)
    log = print

    folder = args.ac_folder or azerothcore.download(args.cache, log=log)
    log("Leyendo AzerothCore...")
    ac_quests = azerothcore.load_quests(folder)
    ac_gossip = azerothcore.load_gossip(folder)

    captured_q, captured_g, scanned = load_captures(sorted(glob.glob(os.path.join(args.capturas, "*.lua"))))
    if args.wowhead:
        # El texto inglés de Wowhead es el de Forever: sustituye al de AzerothCore si cambió.
        # Las capturas del juego tienen prioridad sobre Wowhead.
        wh_ids, wh_quests, _ = wowhead.load_quests(os.path.join(args.data, ".cache", "wowhead"), set(ac_quests),
                                                   args.wowhead_refresh_list, args.wowhead_max, log)
        scanned |= wh_ids
        for qid, en in wh_quests.items():
            merged = dict(en)
            merged.update(captured_q.get(qid, {}))
            captured_q[qid] = merged
    ids_file = os.path.join(args.data, "forever_ids.json")
    forever_ids = set(read_json(ids_file, [])) | scanned
    if scanned:
        write_json(ids_file, sorted(forever_ids))
    # Nunca se descartan misiones de Classic por faltar en un listado: los IDs de Forever solo añaden.
    allowed = forever_ids | {i for i in ac_quests if i < DEFAULT_MAX_ID}

    q_path, g_path = os.path.join(args.data, "quests.json"), os.path.join(args.data, "gossip.json")
    revisions = read_json(os.path.join(args.data, "revisiones.json"), {})
    quests, q_pending = merge_quests(ac_quests, captured_q, read_json(q_path, {}),
                                     revisions.get("quests", {}), allowed)
    gossip, g_pending = merge_gossip(ac_gossip, captured_g, read_json(g_path, {}), revisions.get("gossip", {}))

    names = set(read_json(os.path.join(TOOLS, "names.json"), []))
    ok = failed = 0
    if args.engine != "none":
        engine = get_engine(args.engine, model=args.model) if args.engine == "ollama" else get_engine(args.engine)
        ok, failed = translate_pending(engine, quests, q_pending, gossip, g_pending, names, args.limit, log)

    write_json(q_path, quests)
    write_json(g_path, gossip)
    meta = {"fuente": "AzerothCore " + azerothcore.COMMIT[:10] + (" + Wowhead" if args.wowhead else ""),
            "generado": datetime.date.today().isoformat()}
    nq, ng = generate_lua(quests, gossip, meta, args.addon)
    log(report(quests, gossip))
    log("Traducidos por IA en esta ejecución: %d (fallidos: %d)" % (ok, failed))
    log("Generado: %d misiones y %d claves de diálogo en %s" % (nq, ng, os.path.join(args.addon, "Data")))


if __name__ == "__main__":
    main()
