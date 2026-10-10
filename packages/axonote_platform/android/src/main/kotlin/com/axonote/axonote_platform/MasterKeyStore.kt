package com.axonote.axonote_platform

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

private const val ANDROID_KEYSTORE = "AndroidKeyStore"
private const val KEY_ALIAS_PREFIX = "axonote_mk_"
private const val PREFS_NAME = "axonote_platform_secure"
private const val GCM_TAG_BITS = 128
private const val TRANSFORMATION = "AES/GCM/NoPadding"

/**
 * Guarda y recupera la clave maestra cifrada con una clave de Android Keystore propia de cada
 * cuenta (plan §5.1, §5.2). La clave de Keystore nunca sale del hardware: solo se usa a través de
 * un [Cipher] que el sistema inicializa. El texto cifrado (IV + texto + etiqueta GCM) se guarda en
 * un `SharedPreferences` propio; es opaco sin la clave de Keystore, así que no hace falta cifrarlo
 * de nuevo.
 */
class MasterKeyStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val keyStore: KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    private fun alias(userId: String) = "$KEY_ALIAS_PREFIX$userId"
    private fun ivKey(userId: String) = "iv_$userId"
    private fun cipherTextKey(userId: String) = "ct_$userId"
    private fun requireAuthKey(userId: String) = "auth_$userId"

    fun hasStoredKey(userId: String): Boolean = prefs.contains(cipherTextKey(userId))

    fun requiresAuth(userId: String): Boolean = prefs.getBoolean(requireAuthKey(userId), false)

    /**
     * Genera una clave de Keystore nueva para `userId` (sustituye cualquier clave anterior de esa
     * cuenta: por ejemplo si `requireAuth` cambió) y devuelve un [Cipher] en modo cifrado, listo
     * para usar directamente (`requireAuth = false`) o para envolver en un
     * [androidx.biometric.BiometricPrompt.CryptoObject] (`requireAuth = true`).
     */
    fun prepareEncryptCipher(userId: String, requireAuth: Boolean): Cipher {
        runCatching { keyStore.deleteEntry(alias(userId)) }
        val key = generateKey(alias(userId), requireAuth)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        return cipher
    }

    /** Cifra `plain` con `cipher` (ya autenticado si hacía falta) y lo guarda junto a su IV. */
    fun persistEncrypted(userId: String, cipher: Cipher, plain: ByteArray, requireAuth: Boolean) {
        val cipherText = cipher.doFinal(plain)
        prefs
            .edit()
            .putString(ivKey(userId), Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .putString(cipherTextKey(userId), Base64.encodeToString(cipherText, Base64.NO_WRAP))
            .putBoolean(requireAuthKey(userId), requireAuth)
            .apply()
    }

    /**
     * [Cipher] en modo descifrado para `userId`, listo para usar directamente o para el
     * `CryptoObject`. Lanza [IllegalStateException] si no hay nada guardado, o
     * [android.security.keystore.KeyPermanentlyInvalidatedException] si la clave quedó
     * invalidada (biometría nueva desde que se guardó).
     */
    fun prepareDecryptCipher(userId: String): Cipher {
        val key =
            keyStore.getKey(alias(userId), null) as? SecretKey
                ?: throw IllegalStateException("no hay clave de Keystore para $userId")
        val iv = Base64.decode(prefs.getString(ivKey(userId), null), Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, iv))
        return cipher
    }

    /** Descifra el texto guardado de `userId` con `cipher` (ya autenticado si hacía falta). */
    fun decrypt(userId: String, cipher: Cipher): ByteArray {
        val cipherText = Base64.decode(prefs.getString(cipherTextKey(userId), null), Base64.NO_WRAP)
        return cipher.doFinal(cipherText)
    }

    /** Borra la clave de Keystore y lo guardado de `userId`. No lanza si no había nada. */
    fun delete(userId: String) {
        runCatching { keyStore.deleteEntry(alias(userId)) }
        prefs
            .edit()
            .remove(ivKey(userId))
            .remove(cipherTextKey(userId))
            .remove(requireAuthKey(userId))
            .apply()
    }

    /**
     * Clave AES-256-GCM en Android Keystore. Con `requireAuth`: exige biometría o (API ≥ 30)
     * también la credencial del dispositivo, para cada uso, y se invalida si se registra una
     * biometría nueva (plan §5.2). Usa StrongBox si el dispositivo lo ofrece; si no, TEE.
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
        return try {
            keyGenerator.init(spec(true))
            keyGenerator.generateKey()
        } catch (e: Exception) {
            // Sin StrongBox (StrongBoxUnavailableException) o cualquier otro fallo al pedirlo:
            // reintenta sobre TEE, que todo dispositivo con Keystore soporta.
            keyGenerator.init(spec(false))
            keyGenerator.generateKey()
        }
    }
}
