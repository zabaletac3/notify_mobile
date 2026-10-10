package com.axonote.axonote_platform

import android.app.Activity
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import android.view.WindowManager
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import javax.crypto.Cipher

/**
 * Canal de métodos de `axonote_platform` (plan §5.2): Android Keystore, biometría y
 * `FLAG_SECURE`. Necesita una [FragmentActivity] (`BiometricPrompt` lo exige); por eso
 * `app/android/.../MainActivity.kt` extiende `FlutterFragmentActivity`, no `FlutterActivity`.
 *
 * Códigos de error que puede enviar (ver el lado Dart, `errors.dart`): `auth_cancelled`,
 * `auth_not_enrolled`, `key_invalidated`, `auth_locked_out`, `auth_locked_out_permanent`,
 * `no_stored_key`, y `platform_failure` para cualquier otro fallo. El mensaje que acompaña al
 * error es solo diagnóstico técnico (nunca material secreto ni texto de la persona) y el lado
 * Dart lo ignora: decide únicamente por el código.
 */
class AxonotePlatformPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private lateinit var masterKeyStore: MasterKeyStore
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        masterKeyStore = MasterKeyStore(appContext)
        channel = MethodChannel(binding.binaryMessenger, "axonote_platform")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "storeMasterKey" -> storeMasterKey(call, result)
            "loadMasterKey" -> loadMasterKey(call, result)
            "deleteMasterKey" -> deleteMasterKey(call, result)
            "authAvailability" -> result.success(AuthAvailabilityChecker.compute(appContext))
            "setSecure" -> setSecure(call, result)
            "copySensitive" -> copySensitive(call, result)
            else -> result.notImplemented()
        }
    }

    private fun requireFragmentActivity(result: Result): FragmentActivity? {
        val current = activity
        if (current !is FragmentActivity) {
            result.error("platform_failure", "sin actividad disponible para biometría", null)
            return null
        }
        return current
    }

    private fun storeMasterKey(call: MethodCall, result: Result) {
        val userId = call.argument<String>("userId")
        val bytes = call.argument<ByteArray>("bytes")
        val requireAuth = call.argument<Boolean>("requireAuth") ?: false
        val prompt = call.argument<String>("prompt") ?: "Confirma tu identidad"
        if (userId == null || bytes == null) {
            result.error("platform_failure", "argumentos incompletos", null)
            return
        }

        val pending =
            try {
                masterKeyStore.prepareEncryptCipher(userId, requireAuth)
            } catch (e: AuthNotEnrolledException) {
                bytes.fill(0)
                result.error("auth_not_enrolled", null, null)
                return
            } catch (e: Exception) {
                bytes.fill(0)
                result.error("platform_failure", e.message, null)
                return
            }

        // Cifra y confirma: sustituye el alias activo solo si tiene éxito (ver doc de
        // MasterKeyStore). En cualquier desenlace, la clave maestra en claro se borra de memoria.
        fun succeed(cipher: Cipher) {
            try {
                masterKeyStore.persistEncrypted(userId, pending.slot, cipher, bytes, requireAuth)
                result.success(null)
            } catch (e: Exception) {
                masterKeyStore.abortPending(userId, pending.slot)
                result.error("platform_failure", e.message, null)
            } finally {
                bytes.fill(0)
            }
        }

        fun fail(code: String) {
            masterKeyStore.abortPending(userId, pending.slot)
            bytes.fill(0)
            result.error(code, null, null)
        }

        if (!requireAuth) {
            succeed(pending.cipher)
            return
        }
        val fragmentActivity = requireFragmentActivity(result)
        if (fragmentActivity == null) {
            masterKeyStore.abortPending(userId, pending.slot)
            bytes.fill(0)
            return
        }
        BiometricGate.authenticate(fragmentActivity, pending.cipher, prompt) { authResult ->
            when (authResult) {
                is AuthResult.Success -> succeed(authResult.cipher)
                is AuthResult.Failure -> fail(authResult.code)
            }
        }
    }

    private fun loadMasterKey(call: MethodCall, result: Result) {
        val userId = call.argument<String>("userId")
        val prompt = call.argument<String>("prompt") ?: "Desbloquea AxoNote"
        if (userId == null) {
            result.error("platform_failure", "argumentos incompletos", null)
            return
        }
        if (!masterKeyStore.hasStoredKey(userId)) {
            result.error("no_stored_key", null, null)
            return
        }

        val cipher =
            try {
                masterKeyStore.prepareDecryptCipher(userId)
            } catch (e: MasterKeyInvalidatedException) {
                masterKeyStore.delete(userId)
                result.error("key_invalidated", null, null)
                return
            } catch (e: Exception) {
                result.error("platform_failure", e.message, null)
                return
            }

        fun finishDecrypt(c: Cipher) {
            try {
                result.success(masterKeyStore.decrypt(userId, c))
            } catch (e: MasterKeyInvalidatedException) {
                // El texto cifrado ya es irrecuperable con esta clave: se borra y se pide la
                // contraseña, igual que una biometría nueva.
                masterKeyStore.delete(userId)
                result.error("key_invalidated", null, null)
            } catch (e: Exception) {
                result.error("platform_failure", e.message, null)
            }
        }

        if (!masterKeyStore.requiresAuth(userId)) {
            finishDecrypt(cipher)
            return
        }
        val fragmentActivity = requireFragmentActivity(result) ?: return
        BiometricGate.authenticate(fragmentActivity, cipher, prompt) { authResult ->
            when (authResult) {
                is AuthResult.Success -> finishDecrypt(authResult.cipher)
                is AuthResult.Failure -> result.error(authResult.code, null, null)
            }
        }
    }

    private fun deleteMasterKey(call: MethodCall, result: Result) {
        val userId = call.argument<String>("userId")
        if (userId == null) {
            result.error("platform_failure", "argumentos incompletos", null)
            return
        }
        masterKeyStore.delete(userId)
        result.success(null)
    }

    private fun setSecure(call: MethodCall, result: Result) {
        val secure = call.argument<Boolean>("secure") ?: false
        val current = activity
        if (current == null) {
            result.error("platform_failure", "sin actividad disponible", null)
            return
        }
        if (secure) {
            current.window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        } else {
            current.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        result.success(null)
    }

    private fun copySensitive(call: MethodCall, result: Result) {
        val text = call.argument<String>("text")
        if (text == null) {
            result.error("platform_failure", "argumentos incompletos", null)
            return
        }
        val clipboard = appContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("axonote", text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val extras = PersistableBundle()
            extras.putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            clip.description.extras = extras
        }
        clipboard.setPrimaryClip(clip)
        result.success(null)
    }
}
