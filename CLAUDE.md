# AxoNote móvil — guía para asistentes

App Android en Flutter, paridad funcional con la web. El plan de ejecución completo está en
`docs/plan.md` (plan 0007). **Léelo antes de tocar código**; las decisiones de su §2 están
cerradas y no se cambian.

## Reglas clave

- Una fase por rama (`fase-N-nombre`) y por sesión. No se empieza una fase sin cerrar la anterior.
- Una fase se cierra solo con todo su «Hecho cuando» y las puertas de calidad de la §11.
- Nunca se debilita una prueba ni un vector para que pase.
- Nunca se registran contraseñas, claves, tokens, códigos ni texto de notas. Tampoco en debug.
- `notify_backend` no se toca. `notify_web` solo se toca en la fase 1.
- Comportamiento de referencia: el código de `notify_web` citado en el plan.
- UI en español. Textos de `notify_web/src/lib/core/messages.ts` cuando existan.
- Commits pequeños, uno por tarea, mensaje en español en imperativo.
- Si una decisión resulta imposible: aplicar la alternativa de la §12 del plan. Si no existe,
  parar y anotar el bloqueo en `docs/blockers.md`.

## Stack (decisiones cerradas, §2)

Solo Android (`minSdk 26`) · Riverpod 3 + `go_router` · `drift` + `sqlite3` con
SQLite3MultipleCiphers (`sqlite3mc`) · Argon2id con `sodium` (libsodium) en isolate · AES-GCM y
HKDF con `cryptography` + `cryptography_flutter` · `dio` · editor `appflowy_editor` · Markdown
con códec propio. Identificador provisional `com.axonote.app`.

## Capas

`app/lib/features/<name>/{state,ui}` · datos en `app/lib/data`. `ui` solo habla con `state`;
`state` solo con interfaces de `axonote_domain`; nadie fuera de `app/lib/data` importa `drift`
ni `dio`. Los paquetes puros no importan `package:flutter`.

## Comandos

`flutter pub get` · `dart format --set-exit-if-changed .` · `flutter analyze` · `flutter test`
· `dart tool/check_imports.dart` · `bash tool/check_contract.sh` · `flutter build apk --debug`

## Contrato

`contract/` es copia verificada de `notify_web`. `tool/sync_contract.sh` lo actualiza;
`tool/check_contract.sh` falla en CI si difiere.
