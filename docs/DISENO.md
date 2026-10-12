# Diseño: MisionesES (addon de traducción EN→ES para WoW Forever)

## 1. Contexto y objetivo
- **Jugador:** tiene el juego en **inglés**. Ve la ventana de misión normal y, al lado (o en una ventana bilingüe), el texto en **español**.
- **Experiencia:** instalar y jugar. Sin cuentas, sin claves, sin pasos extra salvo el asistente inicial de 3 clics.
- **Traducción:** por **IA, gratis y automática**. La IA no puede correr dentro del juego, porque un addon no tiene internet. Por eso corre en **GitHub Actions** y llega al jugador como una actualización normal del addon.
- **Descartado:** la API de Blizzard. Probada: Classic da 404, Forever da 403 y retail tiene textos distintos.

### Decisiones tomadas
- **Español:** latino/neutro (estilo esMX, "ustedes").
- **Nombres propios** (lugares, NPCs, facciones, objetos): **siempre en inglés**, para que coincidan con el mapa y el chat.
- **Motor de IA en CI:** Argos Translate.
- **Publicación:** CurseForge, que actualiza el addon solo con su app.

## 2. Arquitectura (3 piezas)
```
┌─────────────── A. ADDON (PC del jugador, juego en inglés) ───────────────┐
│ Eventos WoW ─► Detector ─► Buscador (questID / npcID+hash) ─► Vista      │
│                         └► Recolector (solo mantenedor) ─► SavedVariables│
└──────────────────────────────────────────────────────────────────────────┘
          ▲ actualización (CurseForge)              │ captura EN (mantenedor)
          │                                         ▼
┌──── C. PUBLICACIÓN ────┐   ┌──────────── B. FÁBRICA DE TRADUCCIONES (GitHub) ────────┐
│ tag vX → zip → Release │◄──│ capturas/*.lua → fusionar → traducir solo lo nuevo (IA) │
│ → CurseForge           │   │ → data/*.json (fuente de verdad) → MisionesES/Data/*.lua│
└────────────────────────┘   └─────────────────────────────────────────────────────────┘
```

## 3. Estructura de carpetas
```
Addons/
├─ MisionesES/                  ← lo que se distribuye
│  ├─ MisionesES.toc
│  ├─ Core.lua                  namespace, config, utilidades (Hash, Normalize, Personalize)
│  ├─ Locale.lua                textos de la interfaz del addon
│  ├─ Data/
│  │  ├─ Quests.lua             GENERADO: Q[id] = {...}
│  │  └─ Gossip.lua             GENERADO: G[npcID][hash] = "..."
│  ├─ Logic/
│  │  ├─ Detector.lua           eventos WoW → "qué se está mostrando" (misión+fase, diálogo, registro)
│  │  ├─ Lookup.lua             busca la traducción y la personaliza
│  │  └─ Collector.lua          captura EN de lo que falta + /mes escanear
│  ├─ UI/
│  │  ├─ Parchment.lua          componente pergamino con scroll
│  │  ├─ SidePanel.lua          vista "lateral"
│  │  ├─ Bilingual.lua          vista "bilingüe"
│  │  ├─ QuestLog.lua           registro (al pasar el ratón)
│  │  ├─ Gossip.lua             diálogos
│  │  ├─ Setup.lua              asistente inicial
│  │  └─ Options.lua            panel de opciones
│  └─ Main.lua                  arranque, comandos /mes
├─ data/                        ← fuente de verdad (JSON, revisable en PRs)
│  ├─ quests.json
│  └─ gossip.json
├─ capturas/                    ← SavedVariables subidos por el mantenedor
├─ tools/
│  ├─ luatable.py               leer y escribir tablas Lua
│  ├─ build_db.py               fusionar + traducir + generar Data/*.lua
│  ├─ engines/                  argos.py, ollama.py (misma interfaz translate(list[str]) → list[str])
│  ├─ names.json                nombres propios a conservar en inglés (auto + manual)
│  └─ tests/
├─ .github/workflows/
│  ├─ traducir.yml              push en capturas/ → traduce y commitea Data
│  └─ publicar.yml              tag v* → zip + Release + CurseForge
├─ .pkgmeta
└─ README.md
```

## 4. Modelo de datos

**`data/quests.json`**, fuente de verdad:
```json
"176": {
  "en": { "title": "...", "text": "...", "objectives": "...", "progress": "...", "completion": "..." },
  "es": { "title": "...", "text": "...", ... },
  "hash_en": { "text": "a1b2c3d4", ... },   // detecta si el inglés cambió → retraducir solo ese campo
  "src": "ia" | "revisado"                   // "revisado" = corregido a mano, la IA no lo pisa
}
```

**`MisionesES/Data/Quests.lua`**, generado y solo con ES:
```lua
Q[176] = {title="...", text="...", objectives="...", progress="...", completion="...", src="ia"}
```

**`data/gossip.json`**: `npcID → hashEN → { en, es, src }`. El gossip no tiene ID propio, así que la clave es el npcID más el hash del texto EN normalizado.

**Tokens:**
- `$N` (nombre), `$C` (clase), `$R` (raza) y `$Gél:ella;` (género).
- El recolector sustituye el nombre del jugador por `$N`.
- La IA recibe los tokens protegidos con marcadores y el addon los resuelve al mostrar.

**`MisionesES_Config`** (SavedVariables):
- `setupDone`, `mode` ("lateral"/"bilingue"), `fontSize`.
- `showQuest`, `showQuestLog`, `showGossip`, `collector`.

**`MisionesES_Captura`** (SavedVariables, solo mantenedor):
- `quests[id].en = {...}`
- `gossip[npcID].en[hash] = texto`

## 5. Responsabilidades de los módulos del addon
| Módulo | Entrada | Salida |
|---|---|---|
| Detector | `QUEST_DETAIL/PROGRESS/COMPLETE/FINISHED`, `GOSSIP_SHOW/CLOSED`, hover del registro | `Contexto {tipo, questID, fase, npcID, textoEN}` |
| Lookup | Contexto | `Entrada ES personalizada` o `nil` |
| Vistas | Contexto + Entrada | pergamino lateral o ventana bilingüe; nada si es `nil` |
| Collector | Contexto, cuando `Lookup = nil` y `collector=on` | `MisionesES_Captura` |

Regla: las vistas no leen la API de WoW directamente para decidir. Todo pasa por Detector y Lookup, lo que permite probarlos con un stub.

## 6. Pantallas
1. **Asistente inicial**:
   - Dos tarjetas con vista previa ("Panel lateral" / "Ventana bilingüe").
   - Tamaño de letra y qué traducir.
   - Botones [Vista previa] y [Guardar].
2. **Panel lateral**: pergamino a la derecha de QuestFrame/GossipFrame con el título, el texto y "Objetivos".
3. **Ventana bilingüe**:
   - Cubre QuestFrame, con ES en tinta oscura y EN en tinta clara debajo de cada párrafo.
   - Recompensas y botones Aceptar/Rechazar/Continuar/Completar.
   - Si hay recompensa a elegir, recurre al lateral.
4. **Registro**: al pasar el ratón por el detalle, el pergamino aparece al lado.
5. **Opciones** (Opciones → AddOns → MisionesES): lo mismo que el asistente más "Repetir asistente".
6. Pie "Traducción automática (IA)" cuando `src="ia"`.

**Comandos:**
- `/mes`, `/mes config`, `/mes test`, `/mes modo`.
- Solo mantenedor: `/mes recolector`, `/mes escanear [desde hasta]`, `/mes estado`.

## 7. Fábrica de traducciones (`build_db.py`)
1. Lee `capturas/*.lua` y fusiona el EN en `data/*.json`.
2. Marca como pendiente cada campo nuevo, o cuyo `hash_en` haya cambiado, siempre que `src` no sea `"revisado"`.
3. Protege tokens y **nombres propios** con marcadores para que se queden en inglés.
   - **Nombres automáticos:** el recolector guarda el NPC (`UnitName("npc")`), la zona (`GetZoneText`) y los nombres de los objetivos.
   - **Nombres manuales:** se añaden a mano en `names.json`.
   - **Heurística:** palabras en mayúscula a mitad de frase.
4. Traduce por lotes con el motor configurado (Argos en CI; Ollama opcional en local).
5. Posedita para el español neutro (p. ej. "vosotros" → "ustedes"). Restaura los tokens y valida que conserva los mismos tokens y que el texto no está vacío. Si falla, deja el campo pendiente.
6. Escribe `data/*.json` y regenera `MisionesES/Data/*.lua`, ordenado, para que los diffs queden limpios.

## 8. Publicación
- `traducir.yml`: se dispara con un push a `capturas/**`. Ejecuta `build_db.py` y commitea con el bot.
- `publicar.yml`: se dispara con un tag `v*`. Usa BigWigsMods/packager para publicar en CurseForge (secreto `CF_API_KEY`, ID del proyecto en el `.toc` con `## X-Curse-Project-ID`).
- El jugador recibe la actualización con la app de CurseForge.

## 9. Estado actual vs diseño
- **Hecho (commit `ffc207a`):**
  - las vistas (Parchment, SidePanel, Bilingual, QuestLog, Gossip, Setup, Options);
  - `Core.lua` y `Main.lua`;
  - un recolector orientado al cliente ES.
- **A rehacer:**
  - separar Detector y Lookup;
  - Collector solo EN;
  - `Locale.lua`.
- **Nuevo:**
  - el recolector captura además nombres de NPC, zona y objetivos;
  - `tools/`, `data/`, `capturas/`, los workflows y `.pkgmeta`;
  - borrar `probar_api_blizzard.py`.

## 10. Verificación (cuando se implemente)
- `luac5.1 -p`.
- Smoke test con un stub de la API de WoW (Detector → Lookup → Vista).
- `unittest` de `luatable`, `build_db` (motor falso, tokens, solo-nuevos, "revisado" intocable) y hash Lua = Python.
- Ejecución real de Argos sobre una captura de ejemplo.
- Prueba en el juego.
