package com.axonote.axonote_platform

import android.content.Context
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import javax.crypto.Cipher

/** Resultado de un intento de autenticación con [BiometricPrompt]. */
sealed class AuthResult {
    data class Success(val cipher: Cipher) : AuthResult()

    /** `code` es uno de los que entiende el lado Dart (ver `errors.dart`). */
    data class Failure(val code: String) : AuthResult()
}

/**
 * Envuelve [BiometricPrompt] en una llamada con un único callback, mapeando sus códigos de error a
 * los que espera el lado Dart. En API ≥ 30 permite también la credencial del dispositivo
 * (PIN/patrón/contraseña), igual que describe el plan §5.2.
 */
object BiometricGate {
    fun authenticate(
        activity: FragmentActivity,
        cipher: Cipher,
        title: String,
        onResult: (AuthResult) -> Unit,
    ) {
        val allowDeviceCredential = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
        var delivered = false
        fun deliver(result: AuthResult) {
            // BiometricPrompt puede, en algún dispositivo, llamar a su callback más de una vez
            // para el mismo intento; solo el primer resultado cuenta.
            if (delivered) return
            delivered = true
            onResult(result)
        }

        val executor = ContextCompat.getMainExecutor(activity)
        val callback =
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    deliver(AuthResult.Failure(mapErrorCode(errorCode)))
                }

                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    val resultCipher = result.cryptoObject?.cipher
                    if (resultCipher == null) {
                        deliver(AuthResult.Failure("platform_failure"))
                    } else {
                        deliver(AuthResult.Success(resultCipher))
                    }
                }

                override fun onAuthenticationFailed() {
                    // Una huella o cara no reconocida: no es un error terminal, el cuadro sigue
                    // esperando otro intento. Solo cuentan onAuthenticationError (tras agotarlos)
                    // y onAuthenticationSucceeded.
                }
            }
        val prompt = BiometricPrompt(activity, executor, callback)

        val promptInfoBuilder = BiometricPrompt.PromptInfo.Builder().setTitle(title)
        if (allowDeviceCredential) {
            // Con DEVICE_CREDENTIAL como alternativa, la API prohíbe fijar un botón negativo
            // propio (el sistema ya ofrece "usar PIN" en su lugar).
            promptInfoBuilder.setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
        } else {
            promptInfoBuilder.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            promptInfoBuilder.setNegativeButtonText("Cancelar")
        }

        prompt.authenticate(promptInfoBuilder.build(), BiometricPrompt.CryptoObject(cipher))
    }

    private fun mapErrorCode(errorCode: Int): String =
        when (errorCode) {
            BiometricPrompt.ERROR_USER_CANCELED,
            BiometricPrompt.ERROR_CANCELED,
            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
            -> "auth_cancelled"
            BiometricPrompt.ERROR_LOCKOUT -> "auth_locked_out"
            BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "auth_locked_out_permanent"
            BiometricPrompt.ERROR_NO_BIOMETRICS,
            BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL,
            BiometricPrompt.ERROR_HW_NOT_PRESENT,
            BiometricPrompt.ERROR_HW_UNAVAILABLE,
            -> "auth_not_enrolled"
            else -> "platform_failure"
        }
}

/** Qué puede usar el dispositivo para autenticar, ahora mismo (plan §5.2, ver `types.dart`). */
object AuthAvailabilityChecker {
    fun compute(context: Context): Map<String, Any> {
        val manager = BiometricManager.from(context)
        val strongStatus = manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        val deviceCredentialSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
        val deviceCredentialStatus =
            if (deviceCredentialSupported) {
                manager.canAuthenticate(BiometricManager.Authenticators.DEVICE_CREDENTIAL)
            } else {
                BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED
            }
        val biometricHardwareOk =
            strongStatus != BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE &&
                strongStatus != BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE &&
                strongStatus != BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED
        val enrolled =
            strongStatus == BiometricManager.BIOMETRIC_SUCCESS ||
                deviceCredentialStatus == BiometricManager.BIOMETRIC_SUCCESS
        return mapOf(
            "biometricStrong" to biometricHardwareOk,
            "deviceCredential" to deviceCredentialSupported,
            "enrolled" to enrolled,
        )
    }
}
