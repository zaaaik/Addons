"""Ejecuta tools/tests/smoke.lua con datos reales de data/*.json (requiere lua5.1)."""
import json
import os
import subprocess
import sys

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
import normalize as nz  # noqa: E402


def resolve(t):
    """Simula cómo el juego resuelve una plantilla para Arthas, guerrero humano."""
    t = nz.gender_variants(t)[0]
    for a, b in (("$N", "Arthas"), ("$n", "Arthas"), ("$C", "Warrior"), ("$c", "warrior"),
                 ("$R", "Human"), ("$r", "human"), ("$B", "\n"), ("$b", "\n")):
        t = t.replace(a, b)
    return t


def run(quest_id="62", lua="lua5.1"):
    with open(os.path.join(ROOT, "data", "quests.json"), encoding="utf-8") as f:
        q = json.load(f)[quest_id]
    with open(os.path.join(ROOT, "data", "gossip.json"), encoding="utf-8") as f:
        pair = next(v for v in json.load(f).values() if v["en"] == "Greetings, $n." and v.get("es"))
    return subprocess.run([lua, os.path.join(TOOLS, "tests", "smoke.lua"), os.path.join(ROOT, "MisionesES"),
                           quest_id, resolve(q["en"]["title"]), resolve(q["en"]["text"]),
                           resolve(pair["en"]), pair["es"]], capture_output=True, text=True)


if __name__ == "__main__":
    r = run()
    print(r.stdout, r.stderr)
    sys.exit(r.returncode)
