"""Ollama: modelo de lenguaje local y gratuito (https://ollama.com). Mejor calidad, más lento."""
import json
import urllib.request

PROMPT = (
    "Traduce del inglés al español latino neutro (usa 'ustedes', nunca 'vosotros') este texto de "
    "World of Warcraft. Conserva sin cambios los marcadores como ZQX0ZQ y los nombres propios en inglés. "
    "Responde solo con la traducción.\n\n{text}"
)


class OllamaEngine:
    name = "ollama"

    def __init__(self, model="qwen2.5:7b", url="http://localhost:11434"):
        self.model, self.url = model, url.rstrip("/")

    def translate(self, texts):
        out = []
        for t in texts:
            body = json.dumps({"model": self.model, "prompt": PROMPT.format(text=t), "stream": False,
                               "options": {"temperature": 0.2}}).encode()
            req = urllib.request.Request(self.url + "/api/generate", data=body,
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=300) as r:
                out.append(json.load(r)["response"].strip())
        return out
