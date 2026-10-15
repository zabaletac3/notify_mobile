# Guía · Prueba manual de la fase 10 (editor): web ↔ móvil

Objetivo (§10 «Hecho cuando» (e)): comprobar que una nota escrita en la **web** se ve igual en el
**móvil**, que lo editado en el móvil se ve igual en la web, y que lo que la web no entiende queda
intacto en el móvil. La hace el dueño; el agente no puede hacer el recorrido en el móvil.

Presupuesto: 20–30 minutos. Aparato: ZTE 8050 (Android 13) con la app de depuración instalada, y
`notify_web` levantada en local.

> Regla de oro: **se comparan bytes**, no impresiones. La forma limpia es abrir la misma nota en
> los dos lados y mirar que el Markdown sea idéntico (el móvil conserva el formato de la web).

## Antes de empezar

1. En la web, entra con una cuenta de pruebas y crea la carpeta **`Fase 10`** (para no mezclar).
2. En el móvil, entra con la **misma cuenta** y desbloquea el cofre.
3. Fuerza una sincronización en el móvil (lista → sincronizar) para que la carpeta aparezca.

## Caso 1 · La nota de la web se ve igual en el móvil

1. En la web, crea la nota **`Prueba fase 10`** en la carpeta `Fase 10` y escribe este texto
   (respetando los renglones en blanco):

   ````
   # Resumen de la clase

   La **normalización** evita la *redundancia* y las `anomalías`.

   ## Formas normales

   - 1FN: valores atómicos.
   - 2FN: sin dependencias parciales.
     - 3FN: sin dependencias transitivas.

   ## Pendientes

   - [ ] Repasar dependencias funcionales
   - [x] Taller 4 (diagramas ER)

   > Repasar el capítulo 6 antes del parcial.

   ```js
   const notas = 42;
   ```

   ---

   Visita [AxoNote](https://apunte.app "la web").
   ````
2. Espera a que sincronice y abre la nota en el móvil.
3. Comprueba en el móvil: título grande, negrita, cursiva, código en línea, lista con un nivel
   anidado, lista de tareas (una marcada), cita, bloque de código con lenguaje, separador y enlace.
4. **Vuelve a la web** y no toques nada: la nota debe seguir **idéntica**. (Todo lo que el móvil no
   ha editado viaja byte a byte; no debería haber ni un espacio cambiado.)

## Caso 2 · Lo editado en el móvil se ve igual en la web

1. En el móvil, abre `Prueba fase 10` y **añade al final** un párrafo nuevo: «Añadido desde el
   móvil.»
2. Espera ~1 segundo (se guarda solo, 400 ms después de la última tecla) y fuerza la
   sincronización.
3. Recarga la web. Debe aparecer el párrafo nuevo, y **el resto de la nota igual que antes** (los
   bloques de arriba no cambian ni reformatean).

## Caso 3 · Formato desde la barra del móvil

1. En el móvil, pon el cursor en un párrafo y toca **B** (negrita); escribe unas palabras; toca
   **B** otra vez y escribe. Debe verse negrita solo en medio.
2. Selecciona una línea y conviértela en **lista de tareas** (icono de tareas). Márcala y
   desmárcala.
3. Cambia el estilo de párrafo con el botón **Aa** (Párrafo → Título 1 → …).
4. Sincroniza, recarga la web y comprueba que la web muestra lo mismo (negrita parcial, tarea
   marcada, título).

## Caso 4 · Lo que la web no entiende queda intacto en el móvil

Este caso es la garantía §8.1/§8.2.5: la web **destruye** tablas e imágenes al guardar. Para ver el
bloque opaco hay que meter ese Markdown **saltándose la web** (por ejemplo editando el `.md` a mano
o importándolo cuando exista la importación de la fase 11). Si no se puede, **sáltate este caso y
anótalo**; no invalida la fase.

1. Con una nota cuyo contenido tenga, por ejemplo:

   ```
   | Alumno | Nota |
   | ------ | ---- |
   | Ana    | 4.5  |

   Texto después de la tabla.
   ```
2. En el móvil, la tabla debe verse como una **tarjeta «Bloque no editable»** con el texto original,
   y el párrafo de después como un párrafo normal.
3. Edita el párrafo de después, guarda y sincroniza: la tabla debe seguir **intacta** en el `.md`
   (compruébalo en la web o en la base).

## Anotar el resultado

En la tarjeta de la fase (o en el traspaso), deja:

- qué casos pasaron y cuáles no;
- si algún caso falló, **la nota exacta** (contenido y qué se vio distinto) para reproducirlo;
- si el caso 4 no se pudo hacer, dilo.

No hace falta que toques nada más: los fallos se convierten en tareas del editor.
