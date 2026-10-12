# Diseño v3: MisionesES (traducción EN→ES para WoW Forever)

## 1. Contexto y objetivo
- **Jugador:** tiene el juego en **inglés** y ve al lado de la ventana de misión su texto en **español**, o una ventana bilingüe. Solo instala el addon y pasa por el asistente inicial.
- **Gratis y automático:** la traducción no se hace en el juego, porque un addon no tiene internet. Se genera antes de publicar y llega como una actualización normal desde CurseForge.
- **Cambio respecto a v2:** antes había que capturar cada misión jugando. Ahora la base se **importa de golpe** desde la base de datos abierta de **AzerothCore** (GPL-2), que ya trae el texto inglés y el **español oficial** de las misiones originales. Jugar e IA quedan solo para lo que falte.

### Investigación (AzerothCore `master`, 2026-10)
| Dato | Valor |
|---|---|
| Misiones originales (ID < 9000) | 4.335 |
| …con descripción en español oficial | 3.516 (81 %) |
| …con texto de recompensa ES / de progreso ES | 3.909 / 2.971 |
| Españoles sospechosos (longitud incoherente o texto de Cataclysm) | ~112 (p. ej. 783) |
| `esMX` vs `esES` | 9.272 de 9.458 idénticos: en la práctica un solo español |
| Tokens | `$N $C $R $B $G…;` iguales que en el juego |

Fuera del alcance del análisis:
- **Pendiente de verificar en el juego:** que Forever conserva los IDs de Classic (`/dump GetQuestID()` en 3 o 4 misiones conocidas).
- **Descartados:** la API de Blizzard (Classic 404, Forever 403) y Wowhead (sus términos prohíben extraer datos).

### Decisiones
- **Español:** latino/neutro. La fuente oficial usa `esMX` y recurre a `esES` si falta.
- **Nombres propios:**
  - En el texto oficial importado se quedan **como los tradujo Blizzard** (p. ej. "Villanorte"), porque no se pueden revertir de forma fiable.
  - En el texto traducido por IA se quedan **en inglés**.
- **Motor IA:** Argos Translate en GitHub Actions.
- **Licencia del addon:** GPL-2, compatible con los datos de AzerothCore. Se cita la fuente en el README.
- **Publicación:** CurseForge.

## 2. Arquitectura
```
 ┌──────────── B. FÁBRICA DE DATOS (GitHub Actions) ─────────────────────────────┐
 │ 1. AzerothCore (commit fijado) ─► importar EN + ES oficial ─┐                 │
 │ 2. capturas/*.lua (Forever)     ─► EN nuevo / cambiado      ├─► data/*.json ─►│
 │ 3. Argos (solo huecos y sospechosos) ◄──────────────────────┘   Data/*.lua    │
 └───────────────────────────────────────────────────────────────────────┬───────┘
                                                                         ▼
 ┌──── C. PUBLICACIÓN: tag vX ─► zip ─► CurseForge ─► app del jugador ────┐
                                                                         ▼
 ┌──────────── A. ADDON (jugador, cliente en inglés) ────────────────────────────┐
 │ Eventos ─► Detector ─► Lookup (questID / hash texto) ─► Vista (lateral|bilingüe)
 │                    └─► Collector (mantenedor): EN que falta o que cambió        │
 └────────────────────────────────────────────────────────────────────────────────┘
```

**Prioridad de fuentes por campo:**
1. `revisado`: corrección manual. Nada lo pisa.
2. `oficial`: importado de AzerothCore.
3. `ia`.

Un campo oficial marcado como sospechoso se sustituye por IA, pero se conserva en el JSON por si se revisa a mano.

## 3. Estructura de carpetas
```
Addons/
├─ MisionesES/                     ← se distribuye
│  ├─ MisionesES.toc
│  ├─ Core.lua                     namespace, config, utilidades (Hash, Normalize, Personalize)
│  ├─ Locale.lua                   textos de la interfaz del addon
│  ├─ Data/  Quests.lua · Gossip.lua · Meta.lua   (GENERADOS)
│  ├─ Logic/ Detector.lua · Lookup.lua · Collector.lua
│  ├─ UI/    Parchment · SidePanel · Bilingual · QuestLog · Gossip · Setup · Options
│  └─ Main.lua                     arranque y comandos /mes
├─ data/                           ← fuente de verdad, revisable en PRs
│  ├─ quests.json · gossip.json
│  ├─ forever_ids.json             IDs que existen en Forever (del escaneo)
│  └─ revisiones.json              correcciones manuales
├─ capturas/                       SavedVariables del mantenedor
├─ tools/
│  ├─ importers/azerothcore.py     descarga (commit fijado) y lee el SQL
│  ├─ sqlparse.py · luatable.py    lectores de SQL y de tablas Lua
│  ├─ engines/ argos.py · ollama.py
│  ├─ normalize.py                 hash y normalización idénticos a Core.lua
│  ├─ build_db.py                  importar → fusionar → traducir → generar
│  └─ tests/
├─ .github/workflows/  build-data.yml · publicar.yml
├─ .pkgmeta · LICENSE (GPL-2) · README.md · docs/DISENO.md
```
El SQL descargado (~65 MB) **no se commitea**: se descarga en CI y se guarda en caché.

## 4. Modelo de datos

**`data/quests.json`**
```json
"62": {
  "en":  { "title": "The Fargodeep Mine", "text": "...", "objectives": "...", "progress": "...", "completion": "..." },
  "es":  { "title": "La Mina Abisal", "text": "...", ... },
  "src": { "title": "oficial", "text": "oficial", "progress": "ia", ... },
  "es_oficial_descartado": { "text": "..." },        // si era sospechoso
  "h":   "9f2c11ab"                                    // hash del EN normalizado (title+text)
}
```

**`MisionesES/Data/Quests.lua`**, generado. Solo trae ES y el hash:
```lua
Q[62] = {t="La Mina Abisal", d="…", o="…", p="…", c="…", h="9f2c11ab", ia=1}
```
- Usa claves cortas para reducir el tamaño. Unas 4.300 misiones suponen ~6–8 MB, aceptable.
- `ia=1` indica que algún campo es de IA.

**`data/gossip.json` / `Data/Gossip.lua`:** `G[hashEN] = "texto ES"`.
- Viene de `npc_text` y `npc_text_locale` de AzerothCore y de las capturas.
- **La clave es el hash del texto EN normalizado**, sin npcID, porque AzerothCore no liga cada texto a un NPC concreto.
- Los textos con `$G` generan dos claves, una masculina y otra femenina.

**Normalización para el hash** (idéntica en Lua y Python):
1. Nombre del jugador → `$n`; clase → `$c`; raza → `$r`, todo en el idioma del cliente.
2. `$B` → salto de línea.
3. Espacios colapsados y todo en minúsculas.
4. djb2 de 32 bits en hexadecimal.

**SavedVariables:**
- `MisionesES_Config` guarda `setupDone`, `mode`, `fontSize`, `showQuest`, `showQuestLog`, `showGossip` y `collector`.
- `MisionesES_Captura` (solo mantenedor) guarda:
  - `quests[id].en`: misiones **sin entrada** o cuyo hash EN **no coincide** con `h`. Así se detecta que Forever cambió el texto.
  - `gossip[hash].en`: diálogos sin traducción.
  - `ids[id] = true`: IDs vistos en el escaneo.

## 5. Módulos del addon
| Módulo | Entrada | Salida |
|---|---|---|
| Detector | `QUEST_DETAIL/PROGRESS/COMPLETE/FINISHED`, `GOSSIP_SHOW/CLOSED`, hover del registro | `Contexto {tipo, questID, fase, textoEN}` |
| Lookup | Contexto | Entrada ES personalizada o `nil`, más `desactualizada` si el hash EN no coincide |
| Vistas | Contexto + Entrada | panel lateral o ventana bilingüe; nada si es `nil` |
| Collector | Contexto, cuando falta la entrada o está desactualizada y `collector=on` | `MisionesES_Captura` |

Las vistas no consultan la API de WoW para decidir; todo pasa por Detector y Lookup. Así se pueden probar con un stub.

## 6. Pantallas y comandos
1. **Asistente inicial:** dos tarjetas con vista previa (panel lateral o ventana bilingüe), tamaño de letra, qué traducir, y los botones [Vista previa] y [Guardar].
2. **Panel lateral:** pergamino a la derecha de QuestFrame o GossipFrame.
3. **Ventana bilingüe:** cubre QuestFrame y alterna párrafos ES y EN, con botones de acción. Si hay una recompensa a elegir, se usa el panel lateral.
4. **Registro de misiones:** el pergamino aparece al pasar el ratón por el detalle.
5. **Opciones** (Opciones → AddOns): lo mismo que el asistente, más "Repetir asistente".
6. **Pie del texto:** "Traducción automática (IA)" si `ia=1`; "Puede no coincidir con esta versión" si está desactualizada.

**Comandos:**
- Jugador: `/mes`, `/mes config`, `/mes test`, `/mes modo`.
- Mantenedor: `/mes recolector`, `/mes escanear [desde hasta]` (registra IDs y títulos EN), `/mes estado`.

## 7. Fábrica de datos (`build_db.py`)
1. **Importar AzerothCore** en un commit fijado en `tools/importers/azerothcore.py`:
   - Tablas: `quest_template`, `quest_template_locale`, `quest_offer_reward(_locale)`, `quest_request_items(_locale)`, `npc_text(_locale)`.
   - Toma el ES de `esMX` y recurre a `esES` si falta.
2. **Filtrar:** solo IDs presentes en `forever_ids.json`. Si ese archivo aún no existe, se usan los IDs < 9000.
3. **Detectar sospechosos:**
   - Longitud ES/EN fuera de [0,6, 1,8].
   - Términos posteriores a Classic en ES que no aparecen en EN: Alamuerte, Cataclismo, Crepúsculo…
4. **Fusionar capturas:**
   - Un EN nuevo crea la entrada.
   - Un EN distinto (hash diferente) sustituye al de AzerothCore y marca el campo para retraducir.
5. **Traducir con Argos** los campos sin ES, sospechosos o marcados:
   - Protege tokens y nombres propios (de `names.json` y heurística de mayúsculas).
   - Posedita al español neutro ("vosotros" → "ustedes").
   - Valida que se conservan los tokens; si falla, el campo queda pendiente.
6. **Aplicar `revisiones.json`**.
7. **Generar** `data/*.json` y `MisionesES/Data/*.lua`, ordenados para que los diffs sean limpios. Imprimir un informe de cobertura.

## 8. Automatización
- `build-data.yml`:
  - **Disparadores:** push a `capturas/**`, `data/revisiones.json` o `tools/**`, y ejecución manual.
  - **Pasos:** caché del SQL de AzerothCore y del modelo de Argos, ejecución de `build_db.py` y commit del bot.
- `publicar.yml`:
  - **Disparador:** tag `v*`.
  - **Pasos:** empaqueta con BigWigsMods/packager y publica en CurseForge (secreto `CF_API_KEY`, `## X-Curse-Project-ID` en el `.toc`).

## 9. Estado actual frente al diseño
**Ya hecho (commit `ffc207a`):**
- Las vistas.
- `Core.lua` y `Main.lua`.
- Un recolector básico.

**A rehacer:**
- Separar Detector y Lookup.
- Normalización y hash nuevos.
- Claves cortas en `Data/`.
- Gossip por hash sin npcID.
- Collector solo para EN que falta o cambió.

**Nuevo:**
- `tools/` completo y `data/`.
- Workflows, `.pkgmeta` y `LICENSE`.
- README.

**Eliminar:** `tools/probar_api_blizzard.py`.

## 10. Verificación
- `luac5.1 -p` y un smoke test con un stub de la API de WoW (Detector → Lookup → Vista, colector).
- `unittest`:
  - `sqlparse` con muestras reales.
  - Importador: misión 62 → "La Mina Abisal"; la 783 se detecta como sospechosa.
  - Normalización y hash **Lua = Python** (con `lua5.1`).
  - `build_db` con motor falso: prioridades, `revisado` intocable, retraducción si cambia el hash.
- Ejecución real: importar AzerothCore más Argos sobre unas 20 misiones, revisar `Data/Quests.lua` y el informe de cobertura.
- En el juego:
  - Comprobar los IDs de Forever.
  - Abrir "The Fargodeep Mine" y ver la traducción.
  - Probar el panel lateral y la ventana bilingüe.
