"""Importa misiones y diálogos (inglés + español oficial) de la base de datos abierta de AzerothCore.

Fuente: https://github.com/azerothcore/azerothcore-wotlk (GPL-2.0), data/sql/base/db_world/.
Se fija un commit concreto para que los datos generados sean reproducibles.
"""
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import sqlparse  # noqa: E402

COMMIT = "ed9d632ab61a31fd412ff18d9035b6449fc54a2f"
BASE_URL = "https://raw.githubusercontent.com/azerothcore/azerothcore-wotlk/%s/data/sql/base/db_world/%s.sql"
TABLES = [
    "quest_template", "quest_template_locale",
    "quest_offer_reward", "quest_offer_reward_locale",
    "quest_request_items", "quest_request_items_locale",
    "npc_text", "npc_text_locale", "broadcast_text_locale",
]
# El español latino (esMX) tiene prioridad; esES solo rellena lo que falte.
ES_LOCALES = ("esMX", "esES")


def download(cache_dir, commit=COMMIT, log=print):
    folder = os.path.join(cache_dir, commit)
    os.makedirs(folder, exist_ok=True)
    for t in TABLES:
        path = os.path.join(folder, t + ".sql")
        if os.path.exists(path) and os.path.getsize(path) > 0:
            continue
        log("Descargando %s..." % t)
        tmp = path + ".part"
        urllib.request.urlretrieve(BASE_URL % (commit, t), tmp)
        os.replace(tmp, path)
    return folder


def _clean(v):
    return v.strip() if isinstance(v, str) and v.strip() else None


def _locale_pick(rows, id_key, locale_key, field):
    """{id: texto} tomando el primer locale disponible de ES_LOCALES."""
    by_loc = {}
    for r in rows:
        txt = _clean(r.get(field))
        if txt:
            by_loc.setdefault(r[locale_key], {})[int(r[id_key])] = txt
    out = {}
    for loc in reversed(ES_LOCALES):
        out.update(by_loc.get(loc, {}))
    return out


def load_quests(folder):
    """Devuelve {questID: {"en": {...}, "es": {...}}} con los campos title/text/objectives/progress/completion."""
    def rows(t):
        return sqlparse.load_file(os.path.join(folder, t + ".sql"), t)

    quests = {}
    for r in rows("quest_template"):
        en = {
            "title": _clean(r.get("LogTitle")),
            "text": _clean(r.get("QuestDescription")),
            "objectives": _clean(r.get("LogDescription")),
        }
        quests[int(r["ID"])] = {"en": {k: v for k, v in en.items() if v}, "es": {}}

    loc = rows("quest_template_locale")
    for field, key in (("Title", "title"), ("Details", "text"), ("Objectives", "objectives")):
        for qid, txt in _locale_pick(loc, "ID", "locale", field).items():
            if qid in quests:
                quests[qid]["es"][key] = txt

    for table, field, key in (("quest_request_items", "CompletionText", "progress"),
                              ("quest_offer_reward", "RewardText", "completion")):
        for r in rows(table):
            qid, txt = int(r["ID"]), _clean(r.get(field))
            if qid in quests and txt:
                quests[qid]["en"][key] = txt
        for qid, txt in _locale_pick(rows(table + "_locale"), "ID", "locale", field).items():
            if qid in quests:
                quests[qid]["es"][key] = txt
    return quests


def load_gossip(folder):
    """Devuelve pares (plantilla EN, plantilla ES o None) de todos los textos de npc_text.

    El español sale de broadcast_text_locale (enlazado por BroadcastTextIDn) y, si falta, de npc_text_locale.
    """
    def rows(t):
        return sqlparse.load_file(os.path.join(folder, t + ".sql"), t)

    broadcast = {}
    bt_rows = rows("broadcast_text_locale")
    for loc in reversed(ES_LOCALES):
        for r in bt_rows:
            if r["locale"] == loc:
                d = broadcast.setdefault(int(r["ID"]), {})
                for g, field in ((0, "MaleText"), (1, "FemaleText")):
                    if _clean(r.get(field)):
                        d[g] = _clean(r[field])
    legacy = {}
    nt_rows = rows("npc_text_locale")
    for loc in reversed(ES_LOCALES):
        for r in nt_rows:
            if r["Locale"] == loc:
                legacy.setdefault(int(r["ID"]), {}).update(
                    {k.lower(): _clean(v) for k, v in r.items() if _clean(v)})

    pairs = []
    for r in rows("npc_text"):
        tid = int(r["ID"])
        for i in range(8):
            bid = int(r.get("BroadcastTextID%d" % i) or 0)
            for g in (0, 1):
                key = "text%d_%d" % (i, g)
                en_txt = _clean(r.get(key))
                if not en_txt:
                    continue
                es_txt = broadcast.get(bid, {}).get(g) or legacy.get(tid, {}).get(key)
                pairs.append((en_txt, es_txt))
    return pairs
