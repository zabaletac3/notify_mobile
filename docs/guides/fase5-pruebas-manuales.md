# Guía paso a paso · Pruebas manuales de la Fase 5 (seguridad local)

Estas pruebas no se pueden automatizar del todo: necesitan tocar el sensor de huella, usar el
PIN/patrón del dispositivo, o registrar una biometría nueva en el sistema. El resto de
`axonote_platform` (guardar y cargar sin biometría, borrar, `authAvailability`, `setSecure`,
`copySensitive`) ya está cubierto en `app/integration_test/axonote_platform_test.dart` sin
necesidad de ninguno de estos pasos.

Los comandos de abajo usan `$SERIE` como marcador: sustitúyelo por la serie de tu dispositivo
(columna que da `adb devices`). Esta guía es independiente del modelo concreto: sirve tanto para
un teléfono con sensor de huella como para uno que solo tenga PIN/patrón del sistema (p. ej. el
ZTE de referencia, serie `LZ0V50COPBC002769`, no tiene sensor de huella) — D4 (plan §2 y §5.2)
acepta cualquiera de los dos como alternativa, y la decisión de 2026-10-11 en `docs/decisions.md`
no distingue entre ellos.

## Antes de empezar

1. Conectar el dispositivo por USB con la depuración activada.
2. Comprobar que el dispositivo tiene **al menos un método de desbloqueo configurado**: huella
   dactilar (Ajustes → Seguridad y privacidad → Datos biométricos y contraseñas → Huella dactilar)
   si tiene sensor, o PIN/patrón del sistema si no lo tiene. Si no hay ninguno, configúralo antes
   de seguir: las pruebas de este documento no funcionan sin biometría o credencial del
   dispositivo ya configurada.
3. Desde `notify_mobile-fase-5/app`:

   ```
   flutter pub get
   adb devices   # confirma que el dispositivo aparece y copia su serie en $SERIE
   ```

## Paso a paso 1 · Guardar y cargar con biometría

Prueba: `con requireAuth: true · guardar pide biometría; al autenticar, cargar luego también la
pide y devuelve los mismos bytes`.

```
flutter test integration_test/axonote_platform_test.dart \
  -d $SERIE \
  --dart-define=AXONOTE_MANUAL_BIOMETRIC_TESTS=true \
  --plain-name "guardar pide biometría"
```

1. Al correr el comando, la app se instala y arranca sola en el teléfono.
2. Aparecerá un cuadro de huella pidiendo confirmar **para guardar**: pon el dedo registrado (o,
   en un dispositivo sin sensor de huella, introduce el PIN/patrón).
3. Nada más confirmar, aparecerá un segundo cuadro pidiendo confirmar **para cargar**: autentica
   otra vez.
4. La terminal donde se lanzó `flutter test` debe terminar en verde («All tests passed»).

## Paso a paso 2 · Cancelar el cuadro de biometría

Prueba: `cancelar la biometría · cancelar el cuadro de biometría (botón atrás o "Cancelar") lanza
AuthCancelled`.

```
flutter test integration_test/axonote_platform_test.dart \
  -d $SERIE \
  --dart-define=AXONOTE_MANUAL_BIOMETRIC_TESTS=true \
  --plain-name "cancelar el cuadro de biometría"
```

1. Aparecerá un primer cuadro **para guardar**: autentica correctamente (este primer paso sí
   necesita autenticar).
2. Aparecerá un segundo cuadro con el texto «TOCA "CANCELAR" O EL BOTÓN ATRÁS AHORA»: en vez de
   autenticar, toca el botón «Cancelar» del propio cuadro (o el botón atrás del sistema).
3. La terminal debe terminar en verde.

Si por error autenticas y el cuadro se confirma, la prueba fallará (esperaba `AuthCancelled` y no
lo recibió); simplemente vuelve a correr el comando y esta vez cancela.

## Paso a paso 3 · Una huella nueva no invalida la clave (la más larga)

Prueba: `una huella nueva no invalida la clave guardada · registrar una huella nueva no invalida
la clave: cargar sigue devolviendo los mismos bytes (con huella o PIN/patrón)`.

Comprueba la decisión de 2026-10-11 (`docs/decisions.md`, enmienda al plan §5.2): con `requireAuth`
la clave de Keystore pide biometría **o** credencial del dispositivo a la vez, así que Android la
ata al SID raíz de la credencial, no solo al biométrico — registrar una huella nueva **no** la
invalida (al contrario de lo que decía la primera versión del plan). Esta es la única prueba que
exige salir de la app a mitad de la ejecución.

```
flutter test integration_test/axonote_platform_test.dart \
  -d $SERIE \
  --dart-define=AXONOTE_MANUAL_BIOMETRIC_TESTS=true \
  --plain-name "huella nueva no invalida"
```

1. Aparecerá un cuadro **para guardar**: autentica (con huella si el dispositivo tiene sensor, o
   con PIN/patrón si no).
2. La prueba espera, con un límite de 5 minutos, a que la app vuelva a primer plano después de
   pasar a segundo plano: ahora, **sin cerrar la terminal**, sal de AxoNote (botón atrás o
   recientes) y ve a Ajustes del sistema → Seguridad y privacidad → Huella dactilar. **Si el
   dispositivo tiene sensor de huella**, registra una huella nueva (puede ser otro dedo tuyo; no
   hace falta borrar las que ya había). **Si no tiene sensor de huella** (p. ej. el ZTE), no hay
   nada que registrar: basta con volver a abrir la app para que la prueba continúe.
3. Vuelve a abrir AxoNote (tócalo en recientes o vuelve a lanzarlo). Aparecerá un cuadro **para
   cargar**: autentica con huella (la nueva que acabas de registrar, o cualquier otra) o con
   PIN/patrón. La prueba comprueba que lo cargado son los mismos bytes que se guardaron en el
   paso 1 — si el cuadro se cerrara solo con un error de invalidación, sería una regresión de la
   decisión de 2026-10-11, no el comportamiento esperado.
4. La terminal debe terminar en verde.
5. **Después de esta prueba**, si quieres dejar el teléfono como estaba y registraste una huella
   nueva en el paso 2, bórrala en Ajustes.

## Paso a paso 4 · Cancelar un re-guardado conserva la clave anterior

Prueba: `cancelar al re-guardar conserva la clave anterior intacta · guardar con auth y cancelar
un segundo guardado no deja la cuenta inservible: la clave anterior sigue intacta`. Comprueba que
guardar es atómico: si cancelas un segundo `storeMasterKey` (p. ej. al cambiar de contraseña), la
clave que ya hubiera guardada sigue sirviendo, no queda a medias.

```
flutter test integration_test/axonote_platform_test.dart \
  -d $SERIE \
  --dart-define=AXONOTE_MANUAL_BIOMETRIC_TESTS=true \
  --plain-name "cancelar al re-guardar conserva"
```

1. Aparecerá un primer cuadro para guardar la clave «ORIGINAL»: autentica.
2. Aparecerá un segundo cuadro con el texto «TOCA "CANCELAR"...»: cancélalo (no autentiques).
3. Aparecerá un tercer cuadro pidiendo confirmar para **cargar**: autentica. La prueba comprueba
   que lo cargado es la clave «ORIGINAL» del paso 1, no un fallo ni «no hay nada guardado».
4. La terminal debe terminar en verde.

## Si algo no sale como se describe

Si cualquier paso se comporta distinto de lo escrito aquí (por ejemplo: el cuadro de biometría no
aparece, o `cargar` lanza `KeyInvalidated` tras registrar la huella nueva en un dispositivo API ≥
30, contra lo que dice la decisión de 2026-10-11), anótalo en `docs/decisions.md` bajo «Fase 5» con
lo que pasó de verdad, y si bloquea cerrar la fase, en `docs/blockers.md` (ver §12 y §0 del plan).
