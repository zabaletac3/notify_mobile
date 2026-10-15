# Prueba manual · Fase 11.1 (maqueta de Ajustes)

Objetivo: revisar en el ZTE que las pantallas de Ajustes coinciden con el diseño «Movil v2» antes
de integrar los servicios. **No hay servicios conectados**: los cambios de interruptores y opciones
viven solo en memoria.

## Instalación

```
source /tmp/claude-1000/mobile-env.sh
flutter build apk --debug --dart-define=API_URL=https://3-12-7-249.sslip.io/v1
adb install -r app/build/app/outputs/flutter-apk/app-debug.apk
```

## Recorrido

1. **Entrar**: lista de notas → menú lateral → **Ajustes** → debe abrir el menú de secciones
   (`/settings/menu`). El botón atrás (y el gesto del sistema) vuelven a la lista.
2. **Generales**: Tema (Sistema/Claro/Oscuro), Tamaño del texto, Fuente del editor (Inter),
   Orden de las notas, dos interruptores e Idioma de la app. Tocar Tema/Orden abre la hoja de
   opciones; el interruptor cambia de estado.
3. **Mi cuenta**: tarjeta de perfil (avatar «NA», nombre y correo de muestra); Nombre y Correo abren
   un diálogo de muestra; Contraseña → «Cambiar»; «Cerrar sesión» cierra la sesión de verdad y lleva
   a la bienvenida.
4. **Sincronización y dispositivos**: estado «Todo sincronizado», interruptores de sincronización,
   «Sincronizar ahora» (aviso de fase 11.2) y lista de tres dispositivos con «Quitar».
5. **Privacidad y seguridad**: interruptores de bloqueo, Tiempo de bloqueo (hoja), «Cifrar notas»,
   y las filas Verificación en dos pasos (→ `/settings/two-factor`) y Sesiones activas
   (→ `/settings/sync`).
6. **Almacenamiento y exportación**: uso «180 MB de 1 GB» con barra, desglose y acciones de
   exportar/importar (aviso de fase 11.5).
7. **Eliminar cuenta**: aviso en rojo, campo de **contraseña** (el botón se activa al escribir) y
   «Cancelar», que vuelve.
8. **Acerca de**: logotipo, «AxoNote», versión, filas legales (aviso de fase 11.6) y copyright.
9. **Atrás siempre**: en cada pantalla, el botón de la barra superior y el gesto del sistema vuelven
   a la pantalla anterior; desde el menú, a la lista. Ninguna pantalla deja atrapado.

## Qué revisar

- Colores, tipografía y **medidas** frente al diseño en **claro y oscuro** (Ajustes → Tema).
- Que el interruptor apagado es gris y el encendido azul; que las filas con descripción son más
  altas y las de solo acción más bajas.
- Que ninguna acción «en construcción» parece terminada: muestra el aviso de la subfase.

## 11.2 · Servicios de cuenta (probar contra el backend de QA)

Con una cuenta real iniciada y desbloqueada:

1. **Mi cuenta → Nombre**: cambiarlo; debe quedar y confirmarse con «Nombre actualizado».
2. **Mi cuenta → Correo**: correo nuevo + contraseña → «Enviar código» → llega el código al correo
   nuevo → introducirlo → «Correo actualizado» (el perfil muestra el correo nuevo).
3. **Mi cuenta → Contraseña**: actual + nueva + confirmar → «Contraseña actualizada». Cerrar sesión
   y volver a entrar con la nueva; la contraseña antigua ya no vale y **las notas siguen ahí**.
4. **Sincronización y dispositivos**: debe listar los dispositivos reales; «Quitar» en otro
   dispositivo cierra su sesión. «Sincronizar ahora» fuerza una sincronización.
5. **Almacenamiento**: el uso y el desglose son los reales de la cuenta.
6. **Eliminar cuenta**: **no** probar con la cuenta real salvo que se quiera borrar; exige la
   contraseña, cierra todas las sesiones y deja la app en la bienvenida.

Errores esperados: contraseña incorrecta en los diálogos → mensaje de validación en el campo.

## 11.2b · Ajustes reales (Generales, Privacidad, Sincronización)

Cada ajuste debe tener efecto y **sobrevivir a cerrar y reabrir la app**:

1. **Generales → Tema**: Sistema/Claro/Oscuro cambia toda la app al instante; cerrar y reabrir la
   mantiene.
2. **Generales → Tamaño del texto**: Pequeño/Mediano/Grande cambia el tamaño de la letra de la app.
3. **Generales → Orden de las notas**: la lista pasa a ese orden (y aguantar el cambio al reabrir).
4. **Generales → Abrir con una nota nueva / Mostrar vista previa**: al activarlo, abrir la lista
   crea una nota nueva; al desactivar la vista previa, las tarjetas pierden la línea de texto.
5. **Privacidad → Bloqueo con huella / Bloquear al salir / Tiempo de bloqueo**: cambiar y comprobar
   que el bloqueo se comporta así (p. ej. `never` no bloquea sola; `immediately` al salir).
6. **Privacidad → Cifrar notas**: es informativo (siempre activo).
7. **Privacidad → Verificación en dos pasos / Sesiones activas**: muestran el estado real (2FA y
   número de dispositivos).
8. **Sincronización → Sincronizar automáticamente / Solo con Wi-Fi**: desactivar la automática y
   comprobar que no sincroniza sola; «Sincronizar ahora» sigue funcionando.

## 11.3 · Verificación en dos pasos y clave de recuperación

1. **Ajustes → Privacidad → Verificación en dos pasos → Activar**: contraseña → aparece el QR (con
   el autenticador) y el secreto → código → se muestran los 10 códigos de respaldo (una sola vez).
2. **Desactivar** y **Regenerar códigos**: piden contraseña + código.
3. **Privacidad → Clave de recuperación → Crear nueva**: contraseña → aparece la clave nueva (una
   sola vez, con copiar). Comprobar que la clave vieja ya no sirve en la web.

No ejecutes «Desactivar», «Regenerar» ni «Crear nueva» contra la cuenta real salvo que quieras
cambiar el estado; en las pruebas automáticas van con fakes.


## 11.4 · Enlaces públicos y «Compartir»

Con una cuenta iniciada y desbloqueada:

1. **Editor**: abre una nota → botón **Compartir** (icono) → hoja «Compartir nota».
   - Interruptor **«Cualquiera con el enlace puede ver»** → al activarlo aparece la URL
     (`SHARE_ORIGIN/n/<slug>#k=…`); al desactivarlo se revoca.
   - **Copiar** copia la URL. Pégala en el navegador: la nota se lee en la web (solo lectura).
2. **Lista**: mantén pulsada una nota → **Compartir** → la misma hoja.
3. **Republicar**: con el enlace activo, edita la nota y espera a que guarde (400 ms); vuelve al
   enlace en el navegador y recarga: el texto es el nuevo.
4. **Revocar**: desactiva el interruptor; el enlace deja de abrir (nota no encontrada).

Comprueba que la app no muestra la clave fuera del fragmento de la URL (no se registra en ningún
sitio) y que la URL solo lleva `#k=…` tras `#`.

## 11.5 · Importar y exportar Markdown

1. **Ajustes → Almacenamiento y exportación → Exportar todas las notas**: se abre el selector de
   guardado; guarda el `.zip`. Ábrelo: un `.md` por nota (`# título`, línea en blanco, cuerpo).
2. **Importar notas**: elige uno o varios `.md`/`.markdown`/`.txt` (≤ 2 MB). Si el archivo empieza
   con `# …`, ese es el título; si no, el nombre del archivo. Aparece «N notas importadas» (y los
   omitidos, si los hay).
3. **Editor → Compartir → Exportar como Markdown**: guarda la nota actual como `.md`.
4. **Vaciar papelera**: pide confirmación y vacía la papelera real.

Prueba con un archivo de más de 2 MB (se omite) y con uno con BOM/CRLF (se normaliza).

## 11.6 · Acerca de y legales

1. **Ajustes → Acerca de**: la versión es la del paquete (p. ej. `0.1.0 (build 1)`).
2. Cada fila abre su pantalla: **Notas de la versión** (`/changelog`), **Términos de uso**
   (`/terms`), **Política de privacidad** (`/privacy`), **Licencias de código abierto**
   (página de licencias de Flutter) y **Contacto y soporte** (`/support`). Todas vuelven atrás.
3. Los textos legales muestran el aviso de **borrador** y su versión.

## 11.7 · Editor y repaso de la fase 9

1. **Editor**: abre una nota, edita y comprueba que el título y el cuerpo se guardan (sal y vuelve
   a abrir). Con una sincronización en curso debe verse «Sincronizando…» bajo la barra superior.
2. **Conflicto**: provoca un conflicto (misma nota editada en dos clientes) y ábrela en el editor:
   debe ser de solo lectura y ofrecer la hoja de conflicto.
3. **Repaso visual**: recorre la lista (claro y oscuro), la papelera, las carpetas y la búsqueda
   frente al tablero «Movil v2»; los fondos y tokens deben coincidir.
