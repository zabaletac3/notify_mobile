# AxoNote móvil — guía para asistentes

App Android en Flutter con **paridad funcional con la web**. Lee y escribe exactamente el
mismo formato cifrado y el mismo protocolo de sincronización que `notify_web`.

Fuente de verdad de alcance y decisiones: `docs/plan.md` (plan 0007). Donde haya duda, manda
ese documento sobre este.

## Cómo se trabaja aquí

1. Una fase del plan por rama (`fase-N-nombre`) y por sesión. No se empieza una fase sin cerrar
   la anterior.
2. Una fase se cierra solo cuando se cumple **todo** su «Hecho cuando» y las puertas de calidad
   de la §11 del plan.
3. No se cambia una decisión de la §2 del plan. Si algo la hace imposible, se aplica la
   alternativa ya escrita en la §12. Si no hay alternativa: parar, describir el bloqueo en
   `docs/blockers.md` y esperar.
4. Nunca se debilita una prueba ni un vector para que pase. Si un vector falla, el código está mal.
5. Nunca se registran (logs, excepciones, analítica, capturas) contraseñas, claves, tokens,
   códigos ni texto de notas. Tampoco en modo debug.
6. `notify_backend` no se toca. `notify_web` solo se toca en la fase 1.
7. La referencia de comportamiento es el código de `notify_web`. Ante una duda de comportamiento
   se lee el archivo TypeScript citado en el plan; no se inventa.
8. Textos de interfaz en español, tomados de `notify_web/src/lib/core/messages.ts` cuando existan.
9. Commits pequeños, uno por tarea, mensaje en español en imperativo.

## Decisiones cerradas (resumen; detalle en `docs/plan.md` §2)

- Solo Android. `minSdk 26`. `targetSdk`/`compileSdk`: los que traiga Flutter estable.
- Estado: Riverpod 3 (notifiers a mano) + `go_router`.
- Base local: `drift` sobre `sqlite3` con **SQLite3MultipleCiphers** (`hooks.user_defines.sqlite3.source: sqlite3mc`).
- Argon2id: **libsodium** (`sodium`, `crypto_pwhash`, `argon2id13`), en isolate.
- AES-GCM y HKDF: `cryptography` (`cryptography_flutter`).
- HTTP: `dio` escrito a mano; DTO con clases `sealed` y `fromJson` manual, sin `freezed`.
- Editor: `appflowy_editor`; Markdown con códec propio.
- Identificador provisional: `com.axonote.app`.

## Reglas de dependencia (se verifican en CI, `tool/check_imports.dart`)

```
app ──► axonote_sync ──► axonote_domain
 │  ──► axonote_api  ──► axonote_domain
 │  ──► axonote_crypto (no depende de domain)
 │  ──► axonote_markdown (no depende de nada)
 └──► axonote_platform
```

- Los paquetes puros no importan `package:flutter`.
- `features/*/ui` solo habla con `features/*/state`. El estado solo con interfaces de
  repositorio de `axonote_domain`. Nadie fuera de `app/lib/data` importa `drift` ni `dio`.

## Comandos

`flutter pub get` · `dart format --set-exit-if-changed .` · `flutter analyze` · `flutter test`
· `dart tool/check_imports.dart` · `bash tool/check_contract.sh` · `flutter build apk --debug`

## Contrato

`contract/` es una copia verificada de `notify_web` (`openapi.yaml` + `vectors/*.json`).
Se sincroniza con `tool/sync_contract.sh`; la CI falla con `tool/check_contract.sh` si difiere.
