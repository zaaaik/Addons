"""Argos Translate: traducción automática offline y gratuita (https://github.com/argosopentech/argos-translate)."""


class ArgosEngine:
    name = "argos"

    def __init__(self):
        import argostranslate.package
        import argostranslate.translate

        installed = argostranslate.translate.get_installed_languages()
        if not any(l.code == "en" and any(t.to_lang.code == "es" for t in l.translations_from) for l in installed):
            argostranslate.package.update_package_index()
            pkg = next(p for p in argostranslate.package.get_available_packages()
                       if p.from_code == "en" and p.to_code == "es")
            argostranslate.package.install_from_path(pkg.download())
        self._tr = argostranslate.translate

    def translate(self, texts):
        return [self._tr.translate(t, "en", "es") for t in texts]
