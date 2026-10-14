"""Motores de traducción EN→ES. Todos exponen translate(list[str]) -> list[str]."""


def get_engine(name, **opts):
    if name == "argos":
        from .argos import ArgosEngine
        return ArgosEngine()
    if name == "ollama":
        from .ollama import OllamaEngine
        return OllamaEngine(**opts)
    if name == "fake":
        from .fake import FakeEngine
        return FakeEngine()
    raise ValueError("Motor desconocido: %s" % name)
