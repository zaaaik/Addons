# Lootly

Addon de World of Warcraft que muestra en pantalla lo que looteas (objetos y oro) con ventanas flotantes animadas, con aspecto de cristal translúcido y varios temas.

## Características

- Ventanas flotantes con icono, nombre por calidad, valor de venta y cantidad.
- Animación de entrada y salida suave; duración por defecto de 6 segundos.
- Clic sobre una ventana para cerrar solo esa.
- Fusión de objetos repetidos y resaltado de épicos o superiores.
- 7 temas: Glass, Dark Glass, Black, Elite Dragon, Elite Gold Dragon, Pill y Neon.
- Todas las opciones son comunes a cualquier tema.
- Ventana de configuración con vista previa en vivo.
- Botón en el minimapa.

## Instalación

1. Copia la carpeta `Lootly` a `World of Warcraft/_retail_/Interface/AddOns/` (o `_classic_` según tu versión).
2. Inicia el juego y activa el addon.

## Uso

| Acción | Resultado |
|---|---|
| Clic izquierdo en el botón del minimapa | Abre la configuración |
| Clic derecho en el botón del minimapa | Muestra/oculta el recuadro para colocar dónde sale el loot |
| `/lt` o `/lootly` | Abre la configuración |
| `/lt test` | Muestra ventanas de prueba |
| `/lt unlock` / `/lt lock` | Mueve / fija la posición |
| `/lt reset` | Restablece la configuración |

## Configuración

- **Aspecto:** tema, fuente, tamaño de letra, opacidad, brillo, tamaño de icono y ancho.
- **Comportamiento:** duración, filas máximas y calidad mínima.
- **Contenido:** valor de venta, cantidad, oro, fusión de repetidos, resaltado y sonido.
- **Posición:** lado, dirección en que nace el loot (arriba o abajo) y mover el recuadro.

## Estado

Versión 0.2.0. Aún no probada a fondo en el juego; se agradecen reportes.

Más detalles de diseño en [ESTRUCTURA.md](ESTRUCTURA.md).
