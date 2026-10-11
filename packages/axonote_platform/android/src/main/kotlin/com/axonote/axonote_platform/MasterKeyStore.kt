package com.axonote.axonote_platform

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.util.Base64
import java.security.InvalidAlgorithmParameterException
import java.security.InvalidKeyException
import java.security.KeyStore
import java.security.UnrecoverableKeyException
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

private const val ANDROID_KEYSTORE = "AndroidKeyStore"
private const val KEY_ALIAS_PREFIX = "axonote_mk_"
private const val PREFS_NAME = "axonote_platform_secure"
private const val GCM_TAG_BITS = 128
private const val TRANSFORMATION = "AES/GCM/NoPadding"
private const val SLOT_A = "a"
private const val SLOT_B = "b"

/**
 * La clave guardada ya no se puede recuperar: se quitó el bloqueo de pantalla seguro del
 * dispositivo, o —solo en API 26-29, donde la clave es puramente biométrica— se registró una
 * biometría nueva ([KeyPermanentlyInvalidatedException]; en API ≥ 30, con biometría o credencial
 * combinadas, una huella nueva NO lanza esto: ver la decisión de 2026-10-11 en
 * `docs/decisions.md`); la entrada de Keystore desapareció o no se puede abrir
 * ([UnrecoverableKeyException], [InvalidKeyException] en algunos fabricantes); o el texto cifrado
 * no corresponde a la clave ([javax.crypto.AEADBadTagException] al descifrar). En todos los casos
 * lo correcto es lo mismo: borrar y pedir la contraseña.
 */
class MasterKeyInvalidatedException(message: String) : Exception(message)

/** No hay biometría ni credencial de dispositivo configurada (API 26-29, ver plan §5.2). */
class AuthNotEnrolledException(message: String) : Exception(message)

/**
 * Un cifrado en curso que todavía no se confirmó: la clave de Keystore ya existe bajo un alias
 * «candidato» (no el activo), y nada en `prefs` la referencia todavía. Hasta que
 * [MasterKeyStore.persistEncrypted] tenga éxito, la cuenta sigue leyendo (si había algo) la clave
 * y el texto cifrado anteriores, intactos. `cipher` es el que hay que usar para cifrar (o envolver
 * en un `CryptoObject`); `slot` identifica el alias candidato para [MasterKeyStore.persistEncrypted]
 * o [MasterKeyStore.abortPending].
 */
class PendingEncrypt(val cipher: Cipher, val slot: String)

/**
 * Guarda y recupera la clave maestra cifrada con una clave de Android Keystore propia de cada
 * cuenta (plan §5.1, §5.2). La clave de Keystore nunca sale del hardware: solo se usa a través de
 * un [Cipher] que el sistema inicializa. El texto cifrado (IV + texto + etiqueta GCM) se guarda en
 * un `SharedPreferences` propio; es opaco sin la clave de Keystore, así que no hace falta cifrarlo
 * de nuevo.
 *
 * **Guardar es atómico frente a biometría cancelada o cualquier otro fallo a medio camino.** Cada
 * cuenta tiene dos alias posibles («a» y «b»); `prefs` recuerda cuál está activo. Guardar genera la
 * clave nueva bajo el alias **candidato** (el que no está activo) sin tocar todavía nada activo;
 * solo si [persistEncrypted] se completa (con `commit()`, no `apply()`: no puede quedar a medias)
 * el candidato pasa a ser el activo y se borra el alias anterior. Si algo falla antes de eso
 * ([abortPending]), el candidato se borra y lo que hubiera antes queda intacto y usable.
 */
class MasterKeyStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val keyStore: KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    private fun alias(userId: String, slot: String) = "$KEY_ALIAS_PREFIX${userId}_$slot"

    private fun activeSlotKey(userId: String) = "slot_$userId"

    private fun ivKey(userId: String) = "iv_$userId"

    private fun cipherTextKey(userId: String) = "ct_$userId"

    private fun requireAuthKey(userId: String) = "auth_$userId"

    private fun activeSlot(userId: String): String? = prefs.getString(activeSlotKey(userId), null)

    private fun otherSlot(slot: String?) = if (slot == SLOT_A) SLOT_B else SLOT_A

    fun hasStoredKey(userId: String): Boolean =
        activeSlot(userId) != null && prefs.contains(cipherTextKey(userId))

    fun requiresAuth(userId: String): Boolean = prefs.getBoolean(requireAuthKey(userId), false)

    /**
     * Genera una clave de Keystore nueva, bajo el alias candidato de `userId`, y devuelve un
     * [Cipher] en modo cifrado listo para usar directamente (`requireAuth = false`) o para
     * envolver en un [androidx.biometric.BiometricPrompt.CryptoObject] (`requireAuth = true`). No
     * toca todavía el alias activo ni `prefs`: ver [persistEncrypted] y [abortPending].
     *
     * Lanza [AuthNotEnrolledException] si `requireAuth` y el dispositivo no tiene biometría ni
     * credencial configurada (API 26-29: `InvalidAlgorithmParameterException` de Keystore).
     */
    fun prepareEncryptCipher(userId: String, requireAuth: Boolean): PendingEncrypt {
        val candidateSlot = otherSlot(activeSlot(userId))
        val candidateAlias = alias(userId, candidateSlot)
        // Por si quedó un candidato a medias de un intento previo que no llegó a abortar.
        runCatching { keyStore.deleteEntry(candidateAlias) }
        val key = generateKey(candidateAlias, requireAuth)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        return PendingEncrypt(cipher, candidateSlot)
    }

    /**
     * Cifra `plain` con `cipher` (ya autenticado si hacía falta; normalmente el mismo objeto que
     * entregó [prepareEncryptCipher], o el que devuelve el `CryptoObject` tras autenticar) y, solo
     * si todo sale bien, convierte `slot` en la versión activa de `userId`: escribe `prefs` con
     * `commit()` (no puede quedar a medias) y borra el alias anterior. Si `doFinal` o `commit()`
     * fallan, lanza y dejan el candidato sin confirmar: quien llama debe invocar [abortPending]
     * para limpiarlo (lo anterior sigue intacto mientras tanto).
     */
    fun persistEncrypted(
        userId: String,
        slot: String,
        cipher: Cipher,
        plain: ByteArray,
        requireAuth: Boolean,
    ) {
        val cipherText = cipher.doFinal(plain)
        val previousSlot = activeSlot(userId)
        val ok =
            prefs
                .edit()
                .putString(ivKey(userId), Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                .putString(cipherTextKey(userId), Base64.encodeToString(cipherText, Base64.NO_WRAP))
                .putBoolean(requireAuthKey(userId), requireAuth)
                .putString(activeSlotKey(userId), slot)
                .commit()
        if (!ok) {
            throw IllegalStateException("no se pudieron escribir las preferencias")
        }
        if (previousSlot != null && previousSlot != slot) {
            runCatching { keyStore.deleteEntry(alias(userId, previousSlot)) }
        }
    }

    /** Borra el alias candidato sin confirmar: lo que hubiera activo antes queda intacto. */
    fun abortPending(userId: String, slot: String) {
        runCatching { keyStore.deleteEntry(alias(userId, slot)) }
    }

    /**
     * [Cipher] en modo descifrado para `userId`, listo para usar directamente o para el
     * `CryptoObject`. Lanza [MasterKeyInvalidatedException] si no hay slot activo, si la entrada
     * de Keystore no se puede recuperar, o si quedó invalidada (ver ahí las causas exactas: no
     * siempre es una biometría nueva, ver la decisión de 2026-10-11 en `docs/decisions.md`).
     */
    fun prepareDecryptCipher(userId: String): Cipher {
        val slot =
            activeSlot(userId)
                ?: throw MasterKeyInvalidatedException("sin slot activo para $userId")
        val key =
            try {
                keyStore.getKey(alias(userId, slot), null) as? SecretKey
            } catch (e: UnrecoverableKeyException) {
                null
            } catch (e: InvalidKeyException) {
                null
            }
                ?: throw MasterKeyInvalidatedException(
                    "la entrada de Keystore de $userId no existe o no se puede recuperar"
                )
        val iv = Base64.decode(prefs.getString(ivKey(userId), null), Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        try {
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, iv))
        } catch (e: KeyPermanentlyInvalidatedException) {
            throw MasterKeyInvalidatedException(
                "bloqueo de pantalla seguro quitado, o (solo en API 26-29) biometría nueva registrada"
            )
        }
        return cipher
    }

    /**
     * Descifra el texto guardado de `userId` con `cipher` (ya autenticado si hacía falta). Lanza
     * [MasterKeyInvalidatedException] si el texto cifrado no corresponde a esta clave
     * ([AEADBadTagException]): ese dato ya es irrecuperable, así que toca pedir la contraseña, no
     * un fallo genérico.
     */
    fun decrypt(userId: String, cipher: Cipher): ByteArray {
        val cipherText = Base64.decode(prefs.getString(cipherTextKey(userId), null), Base64.NO_WRAP)
        return try {
            cipher.doFinal(cipherText)
        } catch (e: AEADBadTagException) {
            throw MasterKeyInvalidatedException("el texto cifrado no corresponde a la clave")
        }
    }

    /** Borra ambos alias posibles (activo y candidato) y lo guardado de `userId`. No lanza si no
     * había nada. Usa `commit()`: no puede quedar a medias. */
    fun delete(userId: String) {
        runCatching { keyStore.deleteEntry(alias(userId, SLOT_A)) }
        runCatching { keyStore.deleteEntry(alias(userId, SLOT_B)) }
        prefs
            .edit()
            .remove(ivKey(userId))
            .remove(cipherTextKey(userId))
            .remove(requireAuthKey(userId))
            .remove(activeSlotKey(userId))
            .commit()
    }

    /**
     * Clave AES-256-GCM en Android Keystore. Con `requireAuth`: exige biometría o (API ≥ 30)
     * también la credencial del dispositivo, para cada uso. Usa StrongBox si el dispositivo lo
     * ofrece; si no, TEE.
     *
     * `setInvalidatedByBiometricEnrollment(true)` se deja puesto para todo `requireAuth`, pero en
     * API ≥ 30 no tiene ningún efecto real: al combinar `AUTH_BIOMETRIC_STRONG` con
     * `AUTH_DEVICE_CREDENTIAL`, Android ata la clave al SID raíz de la credencial del dispositivo,
     * no solo al biométrico, así que una huella nueva no la invalida (decisión de 2026-10-11,
     * `docs/decisions.md`: se acepta, no se corrige). En API 26-29 (rama de abajo, sin
     * `setUserAuthenticationParameters`) la clave sigue siendo puramente biométrica, y ahí sí
     * surte efecto: una huella nueva la invalida. No hay contradicción con lo que ofrece el cuadro
     * de biometría en esa misma rama: `BiometricGate.authenticate` tampoco ofrece la credencial
     * del dispositivo como alternativa por debajo de API 30, solo biometría.
     *
     * Solo reintenta sin StrongBox ante [StrongBoxUnavailableException]: cualquier otra excepción
     * se propaga (en particular, [InvalidAlgorithmParameterException] se convierte en
     * [AuthNotEnrolledException] sin reintentar, porque reintentar sin StrongBox no lo arregla).
     */
    private fun generateKey(alias: String, requireAuth: Boolean): SecretKey {
        fun spec(strongBox: Boolean): KeyGenParameterSpec {
            val builder =
                KeyGenParameterSpec.Builder(
                        alias,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                    )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
            if (requireAuth) {
                builder.setUserAuthenticationRequired(true)
                builder.setInvalidatedByBiometricEnrollment(true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    builder.setUserAuthenticationParameters(
                        0,
                        KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    builder.setUserAuthenticationValidityDurationSeconds(-1)
                }
            }
            if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                builder.setIsStrongBoxBacked(true)
            }
            return builder.build()
        }

        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)

        fun generate(strongBox: Boolean): SecretKey {
            keyGenerator.init(spec(strongBox))
            return keyGenerator.generateKey()
        }

        return try {
            generate(true)
        } catch (e: StrongBoxUnavailableException) {
            try {
                generate(false)
            } catch (e2: InvalidAlgorithmParameterException) {
                throw AuthNotEnrolledException(
                    "sin biometría ni credencial de dispositivo configurada"
                )
            }
        } catch (e: InvalidAlgorithmParameterException) {
            throw AuthNotEnrolledException("sin biometría ni credencial de dispositivo configurada")
        }
    }
}
