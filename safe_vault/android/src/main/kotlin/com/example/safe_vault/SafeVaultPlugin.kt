package com.example.safe_vault // Make sure this matches your generated package name!

import android.content.Context
import android.content.SharedPreferences
import androidx.biometric.BiometricManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import androidx.core.content.edit

class SafeVaultPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: FragmentActivity? = null

    private val keyStoreAlias = "safe_vault_master_key"
    private val prefsName = "safe_vault_prefs"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "safe_vault")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)

        when (call.method) {
            "saveSecret" -> {
                val key = call.argument<String>("key") ?: return result.error("invalid_args", "Missing key", null)
                val secret = call.argument<String>("secret") ?: return result.success(false)

                // Extract AndroidOptions
                val title = call.argument<String>("title") ?: "Authenticate"
                val subtitle = call.argument<String>("subtitle") ?: ""
                val description = call.argument<String>("description") ?: ""
                val cancelText = call.argument<String>("negativeButtonText") ?: "Cancel"

                saveSecret(key, secret, title, subtitle, description, cancelText, prefs, result)
            }

            "getSecret" -> {
                val key = call.argument<String>("key") ?: return result.error("invalid_args", "Missing key", null)

                // Extract AndroidOptions
                val title = call.argument<String>("title") ?: "Unlock data"
                val subtitle = call.argument<String>("subtitle") ?: ""
                val description = call.argument<String>("description") ?: ""
                val cancelText = call.argument<String>("negativeButtonText") ?: "Cancel"

                getSecret(key, title, subtitle, description, cancelText, prefs, result)
            }

            "deleteSecret" -> {
                val key = call.argument<String>("key") ?: return result.error("invalid_args", "Missing key", null)
                prefs.edit { remove(key).remove("${key}_iv") }
                result.success(true)
            }

            "isBiometricAvailable" -> {
                val biometricManager = BiometricManager.from(context)
                // We specifically check for BIOMETRIC_STRONG to perfectly match our Keystore rules
                val status = biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                Log.d("SAFE_VAULT", "STATUS (Enrolled Check): $status")

                result.success(status == BiometricManager.BIOMETRIC_SUCCESS)
            }

            "isDeviceSupported" -> {
                val biometricManager = BiometricManager.from(context)
                val status = biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)

                // It is supported as long as it doesn't explicitly tell us the hardware is missing
                result.success(status != BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE)
            }

            else -> result.notImplemented()
        }
    }

    // --- Core Operations --- //

    private fun saveSecret(
        key: String,
        secret: String,
        title: String,
        subtitle: String,
        description: String,
        cancelText: String,
        prefs: SharedPreferences,
        result: Result
    ) {
        try {
            var secretKey = getOrCreateKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")

            try {
                cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            } catch (e: KeyPermanentlyInvalidatedException) {
                Log.w("SAFE_VAULT", "Master key invalidated by new biometric enrollment. Regenerating...")
                val keyStore = KeyStore.getInstance("AndroidKeyStore")
                keyStore.load(null)
                keyStore.deleteEntry(keyStoreAlias)
                secretKey = getOrCreateKey()
                cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            }

            // Pass the extracted UI strings instead of the hardcoded title
            showBiometricPrompt(
                title, subtitle, description, cancelText, cipher,
                onError = { code, message ->
                    result.error(code, message, null)
                },
                onSuccess = { cryptoObject ->
                    try {
                        val encryptedBytes = cryptoObject.cipher?.doFinal(secret.toByteArray())
                        val ivBytes = cryptoObject.cipher?.iv

                        prefs.edit {
                            putString(key, Base64.encodeToString(encryptedBytes, Base64.DEFAULT))
                            putString("${key}_iv", Base64.encodeToString(ivBytes, Base64.DEFAULT))
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("encrypt_error", e.localizedMessage, null)
                    }
                }
            )
        } catch (e: Exception) {
            result.error("encrypt_error", e.localizedMessage, null)
        }
    }

    private fun getSecret(
        key: String,
        title: String,
        subtitle: String,
        description: String,
        cancelText: String,
        prefs: SharedPreferences,
        result: Result
    ) {
        val encryptedBase64 = prefs.getString(key, null)
        val ivBase64 = prefs.getString("${key}_iv", null)

        if (encryptedBase64 == null || ivBase64 == null) {
            return result.success(null)
        }

        try {
            val secretKey = getOrCreateKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            val iv = Base64.decode(ivBase64, Base64.DEFAULT)

            cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(128, iv))

            // Pass the extracted UI strings
            showBiometricPrompt(
                                title, subtitle, description, cancelText, cipher,
                onError = { code, message ->
                    result.error(code, message, null)
                },
                onSuccess = { cryptoObject ->
                    try {
                        // We decode the saved base64 string, we do NOT use "secret" here
                        val encryptedBytes = Base64.decode(encryptedBase64, Base64.DEFAULT)
                        val decryptedBytes = cryptoObject.cipher?.doFinal(encryptedBytes)
                        
                        result.success(String(decryptedBytes!!))
                    } catch (e: Exception) {
                        prefs.edit { remove(key).remove("${key}_iv") }
                        result.error("hardware_desync", "Hardware Keystore desynchronized. Data wiped.", null)
                    }
                }
            )
        } catch (e: Exception) {
            prefs.edit { remove(key).remove("${key}_iv") }
            result.error("hardware_desync", "Cipher initialization failed. Data wiped.", null)
        }
    }

    // --- Biometric UI & Keystore Helpers --- //

    private fun showBiometricPrompt(
        title: String,
        subtitle: String,
        description: String,
        cancelText: String,
        cipher: Cipher,
        onError: (String, String) -> Unit, // Add error callback
        onSuccess: (BiometricPrompt.CryptoObject) -> Unit
    ) {
        val fragmentActivity = activity ?: return onError("activity_error", "Activity not attached")
        val executor = ContextCompat.getMainExecutor(context)

        val promptInfoBuilder = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .setNegativeButtonText(cancelText)

        if (subtitle.isNotEmpty()) promptInfoBuilder.setSubtitle(subtitle)
        if (description.isNotEmpty()) promptInfoBuilder.setDescription(description)

        val promptInfo = promptInfoBuilder.build()

        val biometricPrompt =
            BiometricPrompt(fragmentActivity, executor, object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    if (result.cryptoObject != null) {
                        onSuccess(result.cryptoObject!!)
                    } else {
                        onError("auth_error", "CryptoObject was null")
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    val flutterCode = when (errorCode) {
                        BiometricPrompt.ERROR_USER_CANCELED,
                        BiometricPrompt.ERROR_NEGATIVE_BUTTON -> "user_canceled"

                        BiometricPrompt.ERROR_NO_BIOMETRICS,
                        BiometricPrompt.ERROR_HW_UNAVAILABLE -> "no_biometrics"

                        else -> "auth_error"
                    }
                    onError(flutterCode, errString.toString())
                }
            })

        biometricPrompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore")
        keyStore.load(null)

        if (keyStore.containsAlias(keyStoreAlias)) {
            val entry = keyStore.getEntry(keyStoreAlias, null) as KeyStore.SecretKeyEntry
            return entry.secretKey
        }

        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        keyGenerator.init(
            KeyGenParameterSpec.Builder(keyStoreAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(true) // THIS REQUIRES BIOMETRICS TO USE THE KEY
                .build()
        )
        return keyGenerator.generateKey()
    }

    // --- Activity Lifecycle --- //

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}