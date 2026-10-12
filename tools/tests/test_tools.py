import os
import shutil
import subprocess
import sys
import tempfile
import unittest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)

import build_db  # noqa: E402
import luatable  # noqa: E402
import normalize as nz  # noqa: E402
import protect  # noqa: E402
import sqlparse  # noqa: E402
from engines.fake import FakeEngine  # noqa: E402


class SqlParseTest(unittest.TestCase):
    def test_rows_with_escapes(self):
        sql = (
            "CREATE TABLE `t` (\n  `ID` int,\n  `Text` text,\n  PRIMARY KEY (`ID`)\n) ENGINE=InnoDB;\n"
            "INSERT INTO `t` VALUES\n(1,'It\\'s $N.$B$BOk'),\n(2,NULL),(3,'a''b, (c)');\n"
        )
        rows = sqlparse.load_table(sql, "t")
        self.assertEqual(rows, [{"ID": "1", "Text": "It's $N.$B$BOk"}, {"ID": "2", "Text": None},
                                {"ID": "3", "Text": "a'b, (c)"}])


class LuaTableTest(unittest.TestCase):
    def test_savedvariables(self):
        src = '''
MisionesES_Config = {
	["mode"] = "lateral",
	["fontSize"] = 13,
}
MisionesES_Captura = {
	["quests"] = {
		[62] = {
			["title"] = "The \\"Fargodeep\\" Mine",
			["text"] = "Line1\\nLine2",
		},
	},
	["ids"] = {
		[176] = true,
	},
	["list"] = {
		"a", -- [1]
		"b", -- [2]
	},
}
'''
        sv = luatable.loads_savedvariables(src)
        cap = sv["MisionesES_Captura"]
        self.assertEqual(cap["quests"][62]["title"], 'The "Fargodeep" Mine')
        self.assertEqual(cap["quests"][62]["text"], "Line1\nLine2")
        self.assertEqual(cap["ids"], {176: True})
        self.assertEqual(cap["list"], {1: "a", 2: "b"})
        self.assertEqual(sv["MisionesES_Config"]["fontSize"], 13)

    def test_roundtrip_value(self):
        v = {"t": 'Dice "hola"\n', "ia": 1, "end": "x"}
        text = "X = " + luatable.lua_value(v)
        self.assertEqual(luatable.loads_savedvariables(text)["X"], v)


class NormalizeTest(unittest.TestCase):
    def test_template_forms(self):
        forms = nz.template_forms("Hello, $N the $C.$B$BWell met, $gsir:madam;!")
        self.assertEqual(forms, ["hello, $n the $c. well met, sir!", "hello, $n the $c. well met, madam!"])

    def test_ascii_lower_only(self):
        # Como string.lower de Lua: solo letras ASCII.
        self.assertEqual(nz.finish("  ÁRBOL\n\tGrande "), "Árbol grande")

    def test_hash_matches_lua(self):
        lua = shutil.which("lua5.1") or shutil.which("lua")
        if not lua:
            self.skipTest("lua5.1 no instalado")
        texts = ["hello, $n the $c. well met, sir!", "¡Saludos, $n!", ""]
        script = os.path.join(TOOLS, "tests", "hash_check.lua")
        out = subprocess.run([lua, script, os.path.join(ROOT, "MisionesES", "Core.lua")] + texts,
                             capture_output=True, text=True, check=True).stdout.split()
        self.assertEqual(out, [nz.hash32(t) for t in texts])


class ProtectTest(unittest.TestCase):
    def test_tokens_names_and_gender_survive(self):
        text = "Greetings, $N. Go to Elwynn Forest.$B$BBe careful, $gsir:madam;."
        out = protect.translate_all(FakeEngine(), [text])[0]
        self.assertIn("$N", out)
        self.assertIn("Elwynn Forest", out)
        self.assertIn("$B$B", out)
        self.assertIn("$g[ES] sir:[ES] madam;", out)

    def test_lost_marker_fails(self):
        class Broken:
            name = "broken"

            def translate(self, texts):
                return ["nada" for _ in texts]
        self.assertEqual(protect.translate_all(Broken(), ["Hi $N"]), [None])

    def test_neutral(self):
        self.assertEqual(protect.neutral_spanish("Vosotros y vosotras"), "Ustedes y ustedes")


class MergeTest(unittest.TestCase):
    def setUp(self):
        self.ac = {
            1: {"en": {"title": "Kill boars", "text": "Kill ten boars near the farm, please."},
                "es": {"title": "Matar jabalíes", "text": "Mata diez jabalíes cerca de la granja, por favor."}},
            2: {"en": {"title": "Old", "text": "A short and simple description of this quest here."},
                "es": {"text": "Alamuerte amenaza Azeroth y bla bla bla bla bla bla bla bla bla bla bla."}},
            3: {"en": {"title": "<NYI> Placeholder"}, "es": {}},
        }

    def test_priorities(self):
        prev = {"2": {"src": {"text": "ia"}, "en_h": {"text": build_db.field_hash(self.ac[2]["en"]["text"])},
                      "es": {"text": "Traducción previa"}}}
        rev = {"1": {"title": "Caza de jabalíes"}}
        quests, pending = build_db.merge_quests(self.ac, {}, prev, rev, {1, 2, 3})
        self.assertNotIn("3", quests)                                   # relleno descartado
        self.assertEqual(quests["1"]["src"], {"title": "revisado", "text": "oficial"})
        self.assertEqual(quests["2"]["es"]["text"], "Traducción previa")  # IA reutilizada
        self.assertEqual(quests["2"]["descartado"]["text"], self.ac[2]["es"]["text"])  # sospechoso
        self.assertEqual(pending, [(2, "title")])

    def test_captured_text_overrides_and_retranslates(self):
        captured = {1: {"text": "Kill twelve boars near the farm."}}
        quests, pending = build_db.merge_quests(self.ac, captured, {}, {}, {1})
        self.assertEqual(quests["1"]["en"]["text"], "Kill twelve boars near the farm.")
        self.assertIn((1, "text"), pending)

    def test_generate_lua(self):
        quests, _ = build_db.merge_quests(self.ac, {}, {}, {}, {1})
        gossip, _ = build_db.merge_gossip([("Hello, $n.", "Hola, $n."), ("Bye $N", None)], {}, {}, {})
        tmp = tempfile.mkdtemp()
        os.makedirs(os.path.join(tmp, "Data"))
        nq, ng = build_db.generate_lua(quests, gossip, {"fuente": "test"}, tmp)
        self.assertEqual((nq, ng), (1, 1))
        with open(os.path.join(tmp, "Data", "Quests.lua"), encoding="utf-8") as f:
            lua = f.read()
        self.assertIn('Q[1]={d="Mata diez jabalíes cerca de la granja, por favor."', lua)
        shutil.rmtree(tmp)



class AddonSmokeTest(unittest.TestCase):
    def test_addon_with_real_data(self):
        lua = shutil.which("lua5.1")
        if not lua or not os.path.exists(os.path.join(ROOT, "data", "quests.json")):
            self.skipTest("lua5.1 o data/quests.json no disponibles")
        sys.path.insert(0, os.path.join(TOOLS, "tests"))
        import run_smoke
        for quest_id in ("62", "1450"):  # 1450 usa $c y $g
            r = run_smoke.run(quest_id, lua)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


class WowheadTest(unittest.TestCase):
    PAGE = (
        '<h1 class="heading-size-1">Heart of Disruption</h1>Collect the <a href="/x">Arcane Mote</a> '
        'in Dalaran.<table class="icon-list"></table>'
        '<h2 class="heading-size-3">Description</h2>Hello &lt;name&gt;, my &lt;lad/lass&gt;.<br /><br />'
        'Go now,&nbsp;&lt;class&gt;.<h2 class="heading-size-3"><a>Progress</a></h2>'
        '<div id="lknlksndgg-progress" style="display: none">Done yet?</div>'
        '<h2 class="heading-size-3"><a>Completion</a></h2>'
        '<div id="lknlksndgg-completion" style="display: none">Thanks, &lt;race&gt;.</div><h2>Rewards</h2>'
    )

    def test_parse_quest(self):
        from importers import wowhead
        q = wowhead.parse_quest(self.PAGE)
        self.assertEqual(q, {
            "title": "Heart of Disruption",
            "objectives": "Collect the Arcane Mote in Dalaran.",
            "text": "Hello $N, my $glad:lass;.$B$BGo now, $C.",
            "progress": "Done yet?",
            "completion": "Thanks, $R.",
        })

    def test_listview(self):
        from importers import wowhead
        page = 'x new Listview({template: \'quest\', _truncated: 1, data:[{"id":1,"name":"a]b"},{"id":2}]});'
        data, truncated = wowhead._listview(page)
        self.assertEqual([d["id"] for d in data], [1, 2])
        self.assertTrue(truncated)


if __name__ == "__main__":
    unittest.main()
