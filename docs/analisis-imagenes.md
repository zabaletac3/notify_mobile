# Análisis · Imágenes en las notas (web, responsive móvil y app Android)

> 2026-10-23. Solo análisis: no hay código nuevo. Parte de lo que hay hoy en `notify_backend`, `notify_web` y
> `notify_mobile`, y termina con decisiones que necesito del dueño antes de planificar. Relacionado con B11/W9
> (`faltantes.md`) y con la decisión de dejar las imágenes fuera de v1 del móvil.

## 1. Qué hay hoy (verificado en el código)

| Pieza | Estado |
| --- | --- |
| **Backend** | No existe nada de adjuntos: ni tabla, ni endpoint, ni cuota por archivo. `notes.payload` es texto cifrado `a1.<iv>.<ct>` de **≤ 1,5 MB**; `MAX_BODY_BYTES` = 1 MB y `MAX_SYNC_BODY_BYTES` = 8 MB. La cuota (`quota-exceeded`) solo suma `payload + wrapped_key` de notas y carpetas. |
| **API / UI de espacio** | `StorageUsage` ya trae `imagesBytes` y la pantalla de Almacenamiento lo muestra, pero siempre en 0 (marcador). Cuota de 1 GB por cuenta. |
| **Web (editor)** | TipTap 3 con `StarterKit + Markdown + TaskList/TaskItem`: **sin extensión de imagen**. Los vectores `markdown.json` marcan `![alt](url)` como `supported: false`: la web **degrada la imagen a su texto alternativo** al guardar. CSP: `img-src 'self' data: blob:` (no deja cargar imágenes remotas). |
| **Móvil (editor)** | `axonote_markdown` trata un párrafo con `![..](` como **bloque opaco** (se conserva byte a byte, no se edita). En la barra, el botón de imagen solo muestra «próximamente»; el `appflowy_editor` vendorizado perdió `file_picker` y `device_info_plus` (choque con `win32`/`dbus`). |
| **Cifrado** | Cada nota tiene su clave (`wrapped_key`) envuelta con la clave maestra. Los enlaces públicos usan otra clave (`shareKey`) envuelta con la clave del cofre; la clave del enlace viaja en el fragmento `#`. El servidor nunca ve texto plano. |
| **Enlaces públicos** | `share_links.payload` ≤ 1,5 MB, descifrable sin cuenta con la clave del fragmento. |

Consecuencia inmediata: **hoy una imagen en una nota se pierde si la edita la web** (queda solo el texto alternativo)
y se conserva solo en el móvil. Conviene saberlo para cualquier nota importada con imágenes.

## 2. Requisitos que debe cumplir la función

1. **Cifrado de extremo a extremo**: el servidor guarda solo bytes cifrados; no puede validar tipo ni contenido.
2. **Funciona sin conexión** y sincroniza (cola local) como las notas.
3. **Compatible entre clientes**: el mismo Markdown en web y móvil; vectores compartidos (`contract/`).
4. Cuenta dentro de la **cuota** y de `imagesBytes`.
5. No degradar los clientes ya instalados (ver §6).
6. Imágenes en **enlaces públicos** (decisión en §8).
7. Privacidad: **quitar EXIF** (GPS, modelo del dispositivo) antes de cifrar.

## 3. Diseño propuesto

### 3.1 No incrustar en el Markdown
Descartado el `data:` URI dentro del texto: una foto de 2 MB reventaría `payload` (1,5 MB), inflaría cada sincronización de la nota y
cada edición volvería a subir la imagen. Las imágenes van como **adjuntos cifrados aparte**, y la nota solo lleva una referencia.

### 3.2 Formato de la referencia
`![texto alternativo](axonote-img:<id>)`, con `<id>` UUID generado en el cliente. Sigue siendo Markdown válido; un lector
sin soporte ve el texto alternativo. Va a `markdown.json` como caso nuevo (`supported: true`) y obliga a
regenerar vectores, a un `ImageBlock` en `axonote_markdown` (en vez de opaco) y a una extensión de imagen en TipTap.

### 3.3 Cifrado del adjunto
- Clave: la de la **nota** (`wrapped_key`) con **AAD** = `userId + noteId + attachmentId`, o una clave aleatoria por imagen envuelta con la de la nota.
  La primera es más simple; la segunda permite mover una imagen entre notas sin reencriptar. Recomiendo la primera para v1.
- Formato: el mismo `a1.<iv>.<ct>` en binario/base64url, con vectores nuevos en `docs/api/vectors`.

### 3.4 Procesamiento en el cliente (antes de cifrar)
Reducir a **máx. 2048 px** de lado largo, recomprimir (WebP o JPEG ~80 %), **quitar EXIF**, tope de entrada ~10 MB y de salida
~2 MB. Formatos aceptados: JPEG, PNG, WebP (y GIF solo el primer cuadro). **Rechazar SVG** (riesgo de scripts).
- Web: `createImageBitmap` + `canvas` (también cubre pegar del portapapeles y arrastrar).
- Móvil: `image_picker` / selector de fotos de Android + recompresión en un isolate (`flutter_image_compress` o el paquete `image`).

### 3.5 Backend
- Tabla `attachments(id uuid, user_id, note_id, size, created_at, deleted_at, payload|object_key)` con RLS como el resto.
- Endpoints binarios (`application/octet-stream`, no JSON/base64): `PUT /attachments/{id}`, `GET /attachments/{id}`,
  `DELETE /attachments/{id}`, con `MAX_ATTACHMENT_BYTES` propio (≈ 3 MB cifrado) y límite de tasa.
- Cuota: sumar los adjuntos y rellenar `imagesBytes` en `/storage/usage`.
- Borrado: al purgar la nota (papelera 30 días / borrado definitivo) y un barrido de **huérfanos** (adjuntos sin referencia).
- Almacenamiento (decisión en §8): `bytea` en PostgreSQL con interfaz de almacén intercambiable, o un bucket S3/R2.

### 3.6 Sincronización
Los adjuntos son **inmutables** (id aleatorio): no hay conflictos. El cliente guarda el binario cifrado en su base local
(tabla `attachments`, estado `pendiente/subido`), sube en segundo plano y **descarga bajo demanda** al mostrar la nota, con
una caché limitada (LRU). La nota se puede guardar aunque la imagen aún no haya subido; hasta que suba se ve la copia local.

### 3.7 Enlaces públicos
La imagen debe poder abrirse sin cuenta: al compartir (y al republicar) se **vuelve a cifrar con `shareKey`** y se publica una copia en
`share_attachments` (tabla o `GET /public/shares/{slug}/attachments/{id}`). Es la parte más cara; ver §8.

### 3.8 Interfaz
- **Web (escritorio y responsive):** botón de imagen en la barra del editor, arrastrar y soltar, pegar; bloque con carga progresiva,
  error y «reintentar»; clic para ampliar; ancho al 100 % del contenedor (sin redimensionar manual en v1); menú del bloque: texto alternativo y eliminar.
- **Móvil:** el botón de imagen de la barra (hoy inerte) abre una hoja con «Galería» y «Cámara»; el selector de fotos de Android no pide
  permiso, la cámara sí; el bloque usa `Image.memory` con esqueleto, error y toque para ampliar con zoom; eliminar con confirmación.
  Requiere un `ImageBlockComponentBuilder` propio en el editor vendorizado.
- **Importar/exportar:** exportar a `.zip` con carpeta `images/` y rutas relativas; importar `.md` con imágenes locales queda para después.

## 4. Cambios por repositorio

| Repo | Trabajo |
| --- | --- |
| `notify_backend` | Migración + módulo `attachments`, cuota e `imagesBytes`, límites, borrado/huérfanos, endpoints públicos si hay imágenes en enlaces, pruebas, auditoría (ZAP) y copias de seguridad. |
| `notify_web` | `openapi.yaml`, vectores de cifrado y de Markdown, extensión de imagen de TipTap, cola/caché local, UI del editor, CSP (`blob:` ya está), e2e. |
| `notify_mobile` | Copiar `contract/`, `axonote_markdown` (`ImageBlock`), tabla local y sincronización de adjuntos, selector/cámara/recompresión, bloque del editor, pruebas y goldens, permisos del manifiesto. |

## 5. Plan por fases (una persona, estimación gruesa)

| Fase | Contenido | Tiempo |
| --- | --- | --- |
| I0 | Decisiones de §8 y diseño final del contrato (OpenAPI + vectores). | 0,5 sem |
| I1 | Backend: tabla, endpoints, cuota, borrado, pruebas. | 1–1,5 sem |
| I2 | Web: lectura y render primero (**antes** de permitir insertar), luego inserción, pegar/arrastrar y sincronización. | 1,5 sem |
| I3 | Móvil: `ImageBlock`, lectura y render, luego selector/cámara/recompresión y sincronización. | 2 sem |
| I4 | Enlaces públicos con imágenes y exportar `.zip`. | 1 sem |
| I5 | Endurecimiento: límites, huérfanos, rendimiento con notas de muchas imágenes, auditoría, accesibilidad (texto alternativo). | 1 sem |

Total: **6–7 semanas**. Con agentes en paralelo (backend / web / móvil, tras fijar el contrato en I0) se puede acortar, pero I2 e I3 dependen de I1 para probar la subida real.

## 6. Orden de despliegue y compatibilidad (riesgo principal)

Los clientes viejos **degradan la imagen a texto** (web) o la tratan como opaca (móvil). Si se permite insertar imágenes antes de que
**todos** los clientes sepan leerlas, una edición desde un cliente viejo borraría la referencia. Por eso:
1. Primero publicar los clientes que **leen** `axonote-img:` (web y móvil) y conservan la referencia.
2. Después habilitar la **inserción** (interruptor de configuración/versión mínima de cliente; ver X3 en `faltantes.md`).
3. El backend acepta adjuntos desde I1 sin riesgo (solo almacena).

## 7. Riesgos

- **Crecimiento de la base y de las copias** si los adjuntos van en PostgreSQL (1 GB × usuarios). Mitigar con cuota propia de imágenes y almacén intercambiable.
- **Costo de rendimiento** en móviles modestos al recomprimir; hacerlo en un isolate con tope de tamaño.
- **Imágenes en enlaces públicos**: doble cifrado, republicación y abuso (contenido público sin moderación). Valorar dejarlas para una segunda entrega.
- **EXIF y privacidad**: obligatorio quitarlo; hay que probarlo con una foto con GPS.
- **Contenido no validable** por el servidor (va cifrado): la validación de tipo y tamaño es del cliente; el servidor solo limita bytes y tasa.
- **Vectores y contrato**: cambiar `supported` de la imagen obliga a regenerar `markdown.json` y a actualizar los tres repos en el mismo ciclo.

## 8. Decisiones que necesito de ti

1. **Dónde se guardan los binarios:** (a) `bytea` en PostgreSQL ahora y bucket más adelante *(mi recomendación para empezar)*; (b) bucket S3/R2 desde el inicio (más infraestructura y costos).
2. **Límites:** tamaño máximo por imagen (propongo 2 MB cifrado tras recomprimir) y **cuota de imágenes** por cuenta (¿dentro del 1 GB actual o aparte, p. ej. 200 MB?).
3. **¿Imágenes en enlaces públicos en la primera entrega?** Recomiendo **no**: mostrar un marcador «imagen no disponible en el enlace» y hacerlo en I4.
4. **Formatos:** ¿solo JPEG/PNG/WebP o también GIF animado? (Propongo sin animación.)
5. **Cámara en el móvil:** ¿foto directa desde la cámara en v1 o solo galería?
6. **Sintaxis de referencia:** ¿te sirve `![alt](axonote-img:<id>)` o prefieres otra?
7. **Orden de entrega:** ¿primero web y luego móvil, o ambos a la vez tras el contrato?

## 9. Qué no he verificado
- Cómo se comporta `@tiptap/markdown` al serializar un nodo de imagen personalizado: hay que probarlo y generar el vector real.
- El costo real de recomprimir en el ZTE y en el Tecno (modelo de gama baja).
- Si el vendorizado de `appflowy_editor` admite un bloque de imagen propio sin tocar su núcleo (probable, como se hizo con tareas y código).
- Cómo está desplegada la base (disco del VPS, política de copias) para dimensionar `bytea`.

## 10. Decisiones del dueño (2026-10-23) y su efecto en el diseño

| Decisión | Efecto |
| --- | --- |
| **Guardar en bucket y en PostgreSQL a la vez** (respaldo mutuo) | Escritura doble: el bucket es el **primario** (lectura) y PostgreSQL guarda una copia `bytea` en una tabla aparte (`attachment_blobs`), fuera de las consultas calientes. Un barrido comprueba que ambas copias coincidan (sha256 del cifrado) y repara la que falte. Costo: la base crece hasta el total de imágenes y las copias/WAL también; se acota con la cuota de imágenes y un job que **no** replica a la base los archivos mayores de cierto tamaño si se decide. |
| **Límite de 20 MB por imagen** | `MAX_ATTACHMENT_BYTES` ≈ 20 MB + sobrecarga del cifrado, con su propia ruta (el cuerpo normal sigue en 1 MB); subida binaria, por partes o directa al bucket con URL firmada; con 1 GB de cuota caben ~50 imágenes del máximo, por eso la cuota de imágenes hay que fijarla. Cloudflare permite cuerpos de 100 MB, no es obstáculo. |
| **Imágenes animadas también** (GIF, WebP animado) | **No se recomprimen** (un `canvas` o un recodificador pierden la animación): se conservan los bytes originales tras **eliminar metadatos** (EXIF/XMP) y se validan firma y estructura. La web las anima con `<img>`; en Flutter, `Image.memory` anima GIF/WebP, pero **descodificar un GIF de 20 MB puede ocupar cientos de MB de RAM**: hay que limitar dimensiones/cuadros al mostrar, usar la caché de imágenes acotada y probarlo en el Tecno y el ZTE. Las fijas siguen reduciéndose a ≤ 4096 px (el límite de 20 MB deja de forzar 2048). |

### Cómo serían los enlaces de las imágenes

Hay tres tipos de «enlace», y ninguno es una URL pública de la imagen en claro:

1. **Referencia dentro de la nota (Markdown):** `![texto](axonote-img:<id>)`. No es una URL: es un identificador. Cada cliente
   descarga el binario cifrado, lo descifra con la clave de la nota y lo muestra como `blob:` (web) o `Image.memory` (móvil).
2. **Descarga del binario cifrado (API):** `GET /v1/attachments/{id}` (con sesión) o una **URL firmada del bucket de vida corta**
   (p. ej. 5 min) que apunta al objeto cifrado. El bucket **nunca es público** y la clave jamás sale del cliente.
3. **Enlace público de la nota con imágenes:** el enlace sigue siendo el de hoy, `https://<web>/n/<slug>#<claveDelEnlace>` (la clave va en el
   fragmento y el servidor no la recibe). Para que se vea sin cuenta, al compartir (y al republicar) el cliente **vuelve a cifrar cada imagen con la
   `shareKey`** y la sube como copia pública: `GET /v1/public/shares/{slug}/attachments/{id}`. El navegador del lector la
   descarga, la descifra con la clave del fragmento y la muestra. Al revocar el enlace se borran esas copias.
   - **Una imagen sola no tiene enlace propio** en la primera entrega (por privacidad no hay URL que sirva `<img src>` directo). Si se quisiera
     «compartir solo una imagen», sería un enlace del mismo estilo, `/i/<slug>#<clave>`, como fase posterior.

### Efecto en las fases
- I1 (backend) crece: dos almacenes, sincronizador/reparador, URLs firmadas, `public/shares/.../attachments` y limpieza al revocar.
- I4 (enlaces públicos con imágenes) entra en la primera entrega, no después.
- Nueva prueba obligatoria: **GIF de 20 MB** en el ZTE y el Tecno (memoria y fluidez), y foto con GPS para comprobar que se elimina el EXIF.

### Decisiones que siguen abiertas
Cuota de imágenes por cuenta (¿dentro del 1 GB o aparte?), tamaño máximo de **dimensiones** de las animadas, cámara en el móvil (¿v1 o solo galería?),
si te sirve la sintaxis `axonote-img:<id>` y el orden de entrega (web primero, móvil primero o a la vez).
