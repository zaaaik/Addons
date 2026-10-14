"""Motor de pruebas: no traduce, marca el texto. Útil para tests y ejecuciones en seco."""


class FakeEngine:
    name = "fake"

    def translate(self, texts):
        return ["[ES] " + t for t in texts]
