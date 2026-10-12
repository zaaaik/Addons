# MisionesES

Addon para **World of Warcraft: Forever** que muestra en **español** las misiones y los diálogos de los NPC sin quitar el texto original en inglés. Se puede ver como un panel al lado de la ventana o como una ventana bilingüe.

- Unas 4.000 misiones del Azeroth original usan su traducción **oficial** al español. El resto (huecos y misiones nuevas de Forever) lo traduce una IA gratuita, y en el juego se indica con la nota "Traducción automática (IA)".
- Funciona sin conexión: las traducciones vienen dentro del addon.
- Requiere el juego en **inglés**.

## Para jugadores

1. Instala **MisionesES** desde CurseForge, o copia la carpeta `MisionesES` en `World of Warcraft\<carpeta de Forever>\Interface\AddOns\`.
2. Entra al juego y elige el modo en el asistente inicial.
3. Listo. Para cambiar las opciones: *Opciones → AddOns → MisionesES* o `/mes config`.

| Comando | Qué hace |
|---|---|
| `/mes config` | Abre las opciones |
| `/mes test` | Muestra una vista previa |
| `/mes modo` | Cambia entre panel lateral y ventana bilingüe |
| `/mes asistente` | Repite el asistente inicial |

## Para el mantenedor

### Cómo se genera la base de datos

`tools/build_db.py` hace estos pasos:
1. Importa el texto inglés y el español oficial de las misiones y diálogos de [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) (GPL-2.0, commit fijado en `tools/importers/azerothcore.py`).
2. Descarta las misiones de relleno y los españoles "sospechosos", es decir, los que no corresponden al texto inglés.
3. Fusiona las capturas hechas en el juego (`capturas/*.lua`).
4. Traduce con **Argos Translate** (gratis y sin conexión) solo lo que falta. Los nombres propios se quedan en inglés.
5. Aplica las correcciones manuales de `data/revisiones.json`.
6. Escribe `data/*.json` (la fuente de verdad) y `MisionesES/Data/*.lua` (lo que carga el addon).

```bash
python3 tools/build_db.py                 # importar + traducir con Argos
python3 tools/build_db.py --engine none   # solo el español oficial, sin IA
python3 tools/build_db.py --engine ollama --model qwen2.5:7b   # IA local de más calidad
python3 -m unittest discover -s tools/tests                    # tests
```

Las traducciones de IA ya hechas se reutilizan: solo se traduce de nuevo cuando cambia el texto inglés.

### Capturar misiones de Forever

Sirve para las misiones nuevas o las que cambiaron respecto a Classic:

1. Con el juego en inglés, escribe `/mes recolector`. Desde ese momento se guarda el texto inglés de las misiones y diálogos que **no** tienen traducción o cuyo texto cambió.
2. Opcional: `/mes escanear 1 30000` registra qué IDs de misión existen en Forever, sin visitar a ningún NPC.
3. Escribe `/reload` y copia `WTF\Account\<cuenta>\SavedVariables\MisionesES.lua` a `capturas/` (por ejemplo, `capturas/2026-10-12.lua`).
4. Haz push. El workflow **Generar base de datos** traduce lo nuevo y commitea `data/` y `MisionesES/Data/`.

`/mes estado` muestra cuánto hay capturado.

### Corregir una traducción

Añade la corrección a `data/revisiones.json`. Las correcciones manuales tienen prioridad sobre el texto oficial y sobre la IA:

```json
{ "quests": { "62": { "text": "Texto corregido..." } }, "gossip": { "<hash>": "Texto corregido..." } }
```

### Publicar

1. Crea el proyecto en CurseForge y añade `## X-Curse-Project-ID: <id>` a `MisionesES/MisionesES.toc`.
2. Guarda tu API token de CurseForge como secreto `CF_API_KEY` del repositorio.
3. Crea y sube un tag, por ejemplo `git tag v0.2.0 && git push --tags`. El workflow **Publicar en CurseForge** empaqueta el addon y lo sube.

## Estructura

```
MisionesES/   addon (Core, Locale, Data generada, Logic: Detector/Lookup/Collector, UI)
data/         quests.json, gossip.json, revisiones.json, forever_ids.json
tools/        build_db.py, importadores, motores de IA, tests
capturas/     SavedVariables del recolector
docs/         DISENO.md
```

## Licencia

GPL-2.0. Los textos de las misiones son propiedad de Blizzard Entertainment. Los datos proceden de AzerothCore (GPL-2.0).
