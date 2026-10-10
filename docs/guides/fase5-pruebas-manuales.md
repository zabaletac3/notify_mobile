# Guía paso a paso · Pruebas manuales de la Fase 5 (seguridad local)

Para quien tenga el ZTE en la mano (serie `LZ0V50COPBC002769`). Estas pruebas no se pueden
automatizar del todo: necesitan tocar el sensor de huella o registrar una biometría nueva en el
sistema. El resto de `axonote_platform` (guardar y cargar sin biometría, borrar, `authAvailability`,
`setSecure`, `copySensitive`) ya está cubierto en `app/integration_test/axonote_platform_test.dart`
sin necesidad de ninguno de estos pasos.

## Antes de empezar

1. Conectar el ZTE por USB con la depuración activada.
2. Comprobar que el dispositivo tiene **al menos una huella registrada** (Ajustes → Seguridad y
   privacidad → Datos biométricos y contraseñas → Huella dactilar). Si no hay ninguna, regístrala
   antes de seguir: las pruebas de este documento no funcionan sin biometría ya configurada.
3. Desde `notify_mobile-fase-5/app`:

   ```
   flutter pub get
   adb devices   # confirma que el ZTE aparece
   ```

## Paso a paso 1 · Guardar y cargar con biometría

Prueba: `con requireAuth: true · guardar pide biometría; al autenticar, cargar luego también la
pide y devuelve los mismos bytes`.

```
flutter test integration_test/axonote_platform_test.dart \
  -d LZ0V50COPBC002769 \
  --dart-define=AXONOTE_MANUAL_BIOMETRIC_TESTS=true \
  --plain-name "guardar pide biometría"
```

1. Al correr el comando, la app se instala y arranca sola en el teléfono.
2. Aparecerá un cuadro de huella pidiendo confirmar **para guardar**: pon el dedo registrado.
3. Nada más confirmar, aparecerá un segundo cuadro pidiendo confirmar **para cargar**: pon el dedo
   otra vez.
4. La terminal donde se lanzó `flutter test` debe terminar en verde («All tests passed»).

## Paso a paso 2 · Cancelar el cuadro de biometría

Prueba: `cancelar la biometría · cancelar el cuadro de biometría (botón atrás o "Cancelar") lanza
AuthCancelled`.

```
flutter test integration_test/axonote_platform_test.dart \
  -d LZ0V50COPBC002769 \
  --dart-define=AXONOTE_MANUAL_BIOMETRIC_TESTS=true \
  --plain-name "cancelar el cuadro de biometría"
```

1. Aparecerá un primer cuadro de huella **para guardar**: pon el dedo registrado (este primer paso
   sí necesita autenticar correctamente).
2. Aparecerá un segundo cuadro con el texto «TOCA "CANCELAR" O EL BOTÓN ATRÁS AHORA»: en vez de
   poner el dedo, toca el botón «Cancelar» del propio cuadro (o el botón atrás del sistema).
3. La terminal debe terminar en verde.

Si por error pones el dedo y autentica, la prueba fallará (esperaba `AuthCancelled` y no lo
recibió); simplemente vuelve a correr el comando y esta vez cancela.

## Paso a paso 3 · Invalidación por huella nueva (la más larga)

Prueba: `invalidación por huella nueva · registrar una biometría nueva invalida la clave guardada:
cargar lanza KeyInvalidated y ya no queda nada guardado`.

Esta es la única que exige salir de la app a mitad de la prueba.

```
flutter test integration_test/axonote_platform_test.dart \
  -d LZ0V50COPBC002769 \
  --dart-define=AXONOTE_MANUAL_BIOMETRIC_TESTS=true \
  --plain-name "registrar una biometría nueva invalida"
```

1. Aparecerá un cuadro de huella **para guardar**: pon el dedo registrado.
2. La prueba queda esperando (no hay límite de tiempo corto): ahora, **sin cerrar la terminal**,
   ve a Ajustes del sistema → Seguridad y privacidad → Huella dactilar y **registra una huella
   nueva** (puede ser otro dedo tuyo; no hace falta borrar las que ya había).
3. Vuelve a abrir AxoNote (puede haberse quedado en segundo plano; tócalo en recientes o
   vuelve a lanzarlo). Debería aparecer el cuadro de huella **para cargar**: esta vez, aunque
   pongas el dedo que acabas de registrar, el sistema no debería ni pedirlo como válido para esa
   clave — Android ya invalidó la clave de Keystore al registrar la huella nueva, así que lo
   normal es que el cuadro se cierre solo con el error, sin necesidad de tocar nada.
4. La terminal debe terminar en verde.
5. **Después de esta prueba**, si quieres dejar el teléfono como estaba, borra en Ajustes la
   huella nueva que registraste en el paso 2.

## Si algo no sale como se describe

Si cualquier paso se comporta distinto de lo escrito aquí (por ejemplo: el cuadro de biometría no
aparece, o `cargar` no lanza `KeyInvalidated` tras registrar la huella nueva), anótalo en
`docs/decisions.md` bajo «Fase 5» con lo que pasó de verdad, y si bloquea cerrar la fase, en
`docs/blockers.md` (ver §12 y §0 del plan).
