# Plan de imágenes en las notas (web, responsive y móvil)

Análisis y razones: `docs/analisis-imagenes.md`. Este archivo fija **lo decidido** y **el orden de ejecución**.
Estado: decisiones del dueño del 2026-10-23; las marcadas «propuesta» siguen sin confirmar.

## 1. Decisiones

| # | Tema | Decisión | Estado |
| --- | --- | --- | --- |
| 1 | Almacenamiento | Bucket (primario, lectura) **y** copia `bytea` en PostgreSQL (`attachment_blobs`); barrido y reparación por sha256 del cifrado | Decidido |
| 2 | Tamaño | 20 MB por imagen (cifrado incluido), ruta propia de subida; el cuerpo normal sigue en 1 MB | Decidido |
| 3 | Animadas | GIF/WebP animado permitidos; no se recomprimen, solo se quitan metadatos y se valida la estructura | Decidido |
| 4 | Referencia en la nota | `![alt](axonote-img:<id>)` (identificador, no URL) | Propuesta |
| 5 | Descarga | `GET /v1/attachments/{id}` con sesión o URL firmada del bucket de ~5 min; bucket nunca público | Decidido |
| 6 | Enlace público de la nota | `https://<web>/n/<slug>#<clave>`; imágenes re-cifradas con `shareKey` en `GET /v1/public/shares/{slug}/attachments/{id}`; se borran al revocar. Entra en la primera entrega | Decidido |
| 7 | Enlace de una imagen sola | No en la primera entrega (futuro: `/i/<slug>#<clave>`) | Decidido |
| 8 | Cuota de imágenes | Propuesta: aparte del 1 GB de notas, 500 MB por cuenta (≈25 imágenes máximas) | Propuesta |
| 9 | Dimensiones | Fijas: lado mayor ≤ 4096 px, recomprimidas. Animadas: ≤ 1280 px de lado y ≤ 300 cuadros al mostrar en móvil | Propuesta |
| 10 | Cámara en móvil | Solo galería en v1; cámara después | Propuesta |
| 11 | Orden | Contrato primero; backend; web y móvil en paralelo; lectura antes que inserción | Propuesta |

## 2. Fases

| Fase | Contenido | Hecho cuando |
| --- | --- | --- |
| I0 | Contrato: `openapi.yaml`, vectores de cifrado (clave de nota + AAD userId+noteId+attachmentId) y de Markdown (`axonote-img:` pasa a `supported:true`); copiar a `contract/` del móvil | Los tres repos pasan sus pruebas de vectores |
| I1 | Backend: migración `attachments` + `attachment_blobs`, endpoints (subir, bajar, URL firmada, borrar), cuota e `imagesBytes`, escritura doble, reparador, huérfanos, límites | Pruebas de integración con bucket falso y Postgres; reparación de una copia perdida |
| I2a | Web (lectura): extensión TipTap que conserva y muestra `axonote-img:`, caché local | Una nota con imagen creada en otro cliente se ve y no se pierde al editar |
| I3a | Móvil (lectura): `ImageBlock` en `axonote_markdown`, bloque en el editor, descarga y caché LRU | Igual en móvil; golden contra Pencil |
| — | **Publicar clientes de lectura** y esperar adopción | Evita que un cliente viejo borre la referencia |
| I2b / I3b | Inserción: web (botón, pegar, arrastrar) y móvil (galería), recompresión en isolate, quitar EXIF, animadas sin recomprimir, texto alternativo | Foto con GPS sale sin coordenadas; GIF de 20 MB sin cerrar la app |
| I4 | Imágenes en enlaces públicos (re-cifrado con `shareKey`, revocación) y exportar `.zip` | Lector sin cuenta ve las imágenes; al revocar devuelven 404 |
| I5 | Endurecimiento: límites y tasa, huérfanos, notas con muchas imágenes, accesibilidad, auditoría (ZAP), copias de seguridad | Presupuestos del §11 del plan sin regresión |

Interruptor de inserción por versión mínima de cliente (X3 de `faltantes.md`) entre I2a/I3a y I2b/I3b.
Estimación: 6–7 semanas de una persona; menos con agentes en paralelo tras I0.

## 3. Pruebas obligatorias
- GIF de 20 MB en el ZTE y en el Tecno Camon 40 Pro (memoria y fluidez). **No probado todavía.**
- Foto con GPS: comprobar que se elimina el EXIF.
- Apagar el bucket (o perder un objeto) y comprobar que el reparador lo restaura desde PostgreSQL, y al revés.
- Cliente viejo editando una nota con imagen: la referencia sobrevive.

## 4. Riesgos
- La base y sus copias crecen con todas las imágenes por la copia en PostgreSQL; la cuota (#8) lo acota. Pendiente dimensionar el disco del VPS y la política de copias.
- Descodificar GIF grandes en Flutter puede consumir cientos de MB de RAM.
- Contenido cifrado: el servidor no valida el tipo, solo bytes y tasa; la validación es del cliente.
- Cambiar `supported` en los vectores obliga a actualizar los tres repos en el mismo ciclo.

## 5. Sin verificar
Serialización de un nodo de imagen en `@tiptap/markdown`; si el `appflowy_editor` vendorizado admite un bloque propio sin tocar su núcleo; costo de recomprimir en el ZTE y el Tecno; disco y copias del VPS.
