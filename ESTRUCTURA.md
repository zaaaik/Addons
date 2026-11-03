# ScrollLoot — Estructura

Addon de WoW que muestra en pantalla el loot que recoges (items y oro), con animación.

## Estructura de archivos

```
ScrollLoot/
├── ScrollLoot.toc   # Metadatos, versiones de interfaz y SavedVariables
└── ScrollLoot.lua   # Lógica, interfaz y comandos
```

## Funcionamiento

- **Eventos:** `CHAT_MSG_LOOT` (items), `CHAT_MSG_MONEY` y `PLAYER_MONEY` (oro).
- **Parseo:** patrones construidos desde las cadenas globales localizadas (`LOOT_ITEM_SELF`, etc.).
- **Datos del item:** `C_Item.GetItemInfo` tras cargar con `Item:CreateFromItemLink`.

## Interfaz

- Barra oscura por entrada: icono, nombre coloreado por calidad, cantidad (`x3`), valor de venta en oro/plata/cobre.
- Línea de color a la izquierda según la calidad.
- Entrada deslizándose desde la izquierda, apilada hacia arriba, desvanecimiento a los 4 s.
- Máximo 8 filas simultáneas, reutilizadas mediante un pool.
- Ancla arrastrable; la posición se guarda en `ScrollLootDB`.

## Comandos

| Comando | Acción |
|---|---|
| `/sl test` | Muestra entradas de prueba |
| `/sl unlock` | Desbloquea el ancla para moverla |
| `/sl lock` | Fija el ancla |

## Pendiente

- Panel de opciones (duración, tamaño, posición).
- Filtro por calidad mínima (`db.minQuality` ya soportado en código).
- Fusionar entradas repetidas del mismo item.
- Probar en Retail y Classic.

## Reglas

1. Siempre se sube todo a `main`. Nunca se crean branches.
