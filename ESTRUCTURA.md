# Lootly — Estructura

Addon de WoW. Al lootear cualquier cosa (enemigo, cofre, mineral, hierba, correo, etc.) muestra en pantalla lo recogido, como en el GIF de referencia (SkyesScrollingLoot), pero con aspecto **flotante, translúcido, estilo "liquid glass" de iPhone**.

## Reglas

1. Siempre se sube todo a `main`. Nunca se crean branches.
2. Todo se trabaja en la carpeta local; solo se sube a `main` cuando el usuario lo indique.

## Estructura de archivos

```
Lootly/
├── Lootly.toc   # Metadatos, versiones, SavedVariables, orden de carga
├── Locales.lua      # Textos ES / EN
├── Core.lua         # Valores por defecto, base de datos, comandos
├── Style.lua        # Motor de temas
├── Themes/
│   ├── Glass.lua    # Transparente liquid glass (principal)
│   ├── DarkGlass.lua # Cristal oscuro translúcido
│   ├── Black.lua    # Negro sólido, más compacto
│   ├── EliteDragon.lua # Elite Dragon: anillo de dragón + barra de acero con borde dorado; cantidad en el círculo pequeño (diseño D3)
│   ├── EliteGoldDragon.lua # Elite Gold Dragon: anillo dorado + barra de bronce cálido (diseño 4)
│   ├── Pill.lua     # Pastilla minimalista
│   └── Neon.lua     # Borde de color con resplandor
├── Media/
│   ├── dragon_ring.tga       # Anillo plateado (Elite Dragon)
│   └── gold_dragon_ring.tga  # Anillo dorado (Elite Gold Dragon)
├── Display.lua      # Filas flotantes: pool, animación, apilado, fusión
├── Loot.lua         # Eventos de loot/oro y parseo
├── RollChat.lua     # Resumen de tiradas (Necesidad/Codicia/Pasar) en el chat
├── Config.lua       # Ventana de configuración
└── Minimap.lua      # Botón del minimapa
```

## Funcionamiento

- **Eventos:** `CHAT_MSG_LOOT` (items), `CHAT_MSG_MONEY` (oro), reputación opcional.
- **Parseo:** patrones desde las cadenas globales localizadas (`LOOT_ITEM_SELF`, etc.).
- **Datos del item:** `C_Item.GetItemInfo` tras cargar con `Item:CreateFromItemLink`.
- **Valor:** precio de venta × cantidad en oro/plata/cobre.

## Temas (diseños)

- Habrá ≈10 diseños. El principal es **Glass** (transparente); otros: **Black** (negro, otro tamaño), **Elite Dragon** (aspecto dragón, no transparente), etc.
- Cada tema solo define lo **visual**: texturas, fondo, borde, forma, tamaño base, animación de entrada y disposición de los elementos.
- Se elige en el menú de configuración con vista previa.
- **Las opciones de configuración son estándar y comunes a todos los temas** (letra, opacidad, posición, duración, filtros, etc.); el tema solo aporta los valores base y cómo se dibujan.
- Cada tema se registra con una tabla común: `Style:Register(nombre, { crearFila, aplicar, tamaño, animación })`. Añadir un diseño nuevo = añadir un archivo en `Themes/`.

## Aspecto base (tema Glass, liquid glass)

- Fondo translúcido con desenfoque aparente: capa oscura/clara a baja opacidad.
- Borde fino con brillo superior (reflejo) y esquinas muy redondeadas.
- Sombra suave que da sensación de flotar.
- Línea o resplandor del color de la calidad del item.
- Icono, nombre por calidad, valor bajo el nombre y cantidad (solo el número, también 1) en una caja pequeña al final de la barra, igual en todos los temas.
- Animación: entra deslizando con rebote suave, se apila, se desvanece al final.

## Menú de configuración

Ventana con barra lateral (Aspecto, Comportamiento, Contenido, Posición), vista previa en vivo a la derecha (con el tema elegido) y botones Probar / Desbloquear / Restablecer. Los selectores se cambian con flechas izquierda y derecha.

Opciones previstas:

**Aspecto**
- Selector de tema (≈10 diseños) con vista previa.
- Tamaño de letra del nombre y del valor.
- Fuente.
- Opacidad del cristal (de muy transparente a sólido).
- Intensidad del brillo y del borde.
- Redondeo de esquinas.
- Tamaño del icono y ancho/alto de la fila.
- Color de acento: por calidad del item o fijo.
- Tema: cristal claro, cristal oscuro, tintado.

**Posición y animación**
- Mover el ancla arrastrando, con vista previa.
- Dirección en que nace y crece el loot (hacia arriba / hacia abajo) y lado de entrada (izquierda/derecha).
- Duración en pantalla y velocidad de animación.
- Máximo de filas simultáneas.

**Contenido**
- Calidad mínima a mostrar.
- Mostrar/ocultar: cantidad, valor de venta, oro, reputación, items de misión.
- Fusionar entradas repetidas del mismo item.
- Resaltar items valiosos (épicos o precio mínimo) con brillo extra.
- Sonido opcional al recoger items raros.

**Otros**
- Botón de prueba (`/lt test`).
- Restablecer valores por defecto.
- Perfiles por personaje o compartidos.

## Botón del minimapa

- Clic izquierdo: abrir/cerrar la configuración.
- Clic derecho: muestra/oculta el recuadro para colocar manualmente dónde sale el loot (arrastrar y volver a clic derecho para fijar).
- Arrastrar para reposicionar alrededor del minimapa; opción para ocultarlo.

## Comandos

| Comando | Acción |
|---|---|
| `/lt` o `/lootly` | Abre la configuración |
| `/lt test` | Entradas de prueba |
| `/lt unlock` / `/lt lock` | Mover / fijar el ancla |

## Estado

Implementado (v0.2.0, sin probar en el juego): todo lo anterior salvo temas adicionales, reputación y perfiles.

## Orden de desarrollo

1. Núcleo: eventos, parseo y filas básicas.
2. Motor de temas y tema Glass con animaciones.
3. Resto de temas (Black, Elite Dragon, etc.).
4. Base de datos y valores por defecto.
5. Ventana de configuración.
6. Botón del minimapa.
7. Textos ES/EN y pruebas en Retail y Classic.
