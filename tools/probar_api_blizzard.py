#!/usr/bin/env python3
"""Prueba si la API de Blizzard devuelve misiones en español para cada namespace.

Lee BLIZZARD_CLIENT_ID y BLIZZARD_CLIENT_SECRET del entorno.
Uso: python3 tools/probar_api_blizzard.py [questID ...]
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

NAMESPACES = ["static-us", "static-classic-us", "static-classic1x-us", "static-forever-us"]
LOCALES = ["es_ES", "es_MX"]
DEFAULT_QUESTS = [176, 783]  # 176 "Wanted: Hogger", 783 "A Threat Within" (vanilla)


def token(client_id, secret):
    req = urllib.request.Request(
        "https://oauth.battle.net/token",
        data=b"grant_type=client_credentials",
        headers={"Authorization": "Basic " + base64.b64encode(f"{client_id}:{secret}".encode()).decode()},
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)["access_token"]


def get_quest(tok, quest_id, namespace, locale):
    qs = urllib.parse.urlencode({"namespace": namespace, "locale": locale})
    req = urllib.request.Request(
        f"https://us.api.blizzard.com/data/wow/quest/{quest_id}?{qs}",
        headers={"Authorization": f"Bearer {tok}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, None


def main():
    cid, secret = os.environ.get("BLIZZARD_CLIENT_ID"), os.environ.get("BLIZZARD_CLIENT_SECRET")
    if not cid or not secret:
        sys.exit("Faltan BLIZZARD_CLIENT_ID / BLIZZARD_CLIENT_SECRET en el entorno.")
    quests = [int(q) for q in sys.argv[1:]] or DEFAULT_QUESTS
    tok = token(cid, secret)
    print("Token OK")
    for ns in NAMESPACES:
        for loc in LOCALES:
            for q in quests:
                status, data = get_quest(tok, q, ns, loc)
                if data:
                    fields = sorted(data.keys())
                    print(f"[{status}] {ns} {loc} {q}: {data.get('title')!r} campos={fields}")
                    desc = data.get("description")
                    if desc:
                        print(f"      descripción: {desc[:120]!r}")
                else:
                    print(f"[{status}] {ns} {loc} {q}")


if __name__ == "__main__":
    main()
