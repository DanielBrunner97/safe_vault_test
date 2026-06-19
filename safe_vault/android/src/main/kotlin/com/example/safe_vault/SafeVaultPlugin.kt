package com.example.safe_vault // Make sure this matches your generated package name!

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
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

class SafeVaultPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel : MethodChannel
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
        val key = call.argument<String>("key") ?: return result.error("invalid_args", "Missing key", null)
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)

        when (call.method) {
            "saveSecret" -> {
                val secret = call.argument<String>("secret") ?: return result.success(false)
                saveSecret(key, secret, prefs, result)
            }
            "getSecret" -> getSecret(key, prefs, result)
            "deleteSecret" -> {
                prefs.edit().remove(key).remove("${key}_iv").apply()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // --- Core Operations --- //

    private fun saveSecret(key: String, secret: String, prefs: SharedPreferences, result: Result) {
        try {
            val secretKey = getOrCreateKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)

            showBiometricPrompt("Authenticate to secure your data", cipher) { cryptoObject ->
                if (cryptoObject == null) {
                    result.success(false)
                    return@showBiometricPrompt
                }
                
                try {
                    val encryptedBytes = cryptoObject.cipher?.doFinal(secret.toByteArray())
                    val ivBytes = cryptoObject.cipher?.iv

                    // Save IV and Ciphertext to SharedPreferences
                    prefs.edit()
                        .putString(key, Base64.encodeToString(encryptedBytes, Base64.DEFAULT))
                        .putString("${key}_iv", Base64.encodeToString(ivBytes, Base64.DEFAULT))
                        .apply()
                        
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
        } catch (e: Exception) {
            result.error("encrypt_error", e.localizedMessage, null)
        }
    }

    private fun getSecret(key: String, prefs: SharedPreferences, result: Result) {
        val encryptedBase64 = prefs.getString(key, null)
        val ivBase64 = prefs.getString("${key}_iv", null)

        if (encryptedBase64 == null || ivBase64 == null) {
            return result.success(null)
        }

        try {
            val secretKey = getOrCreateKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            val iv = Base64.decode(ivBase64, Base64.DEFAULT)
            
            // [XIAOMI BUG CATCHER STAGE 1] 
            // If the hardware keystore desyncs, it often fails right here during initialization.
            cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(128, iv))

            showBiometricPrompt("Unlock your secure data", cipher) { cryptoObject ->
                if (cryptoObject == null) {
                    result.success(null)
                    return@showBiometricPrompt
                }
                
                try {
                    val encryptedBytes = Base64.decode(encryptedBase64, Base64.DEFAULT)
                    // [XIAOMI BUG CATCHER STAGE 2]
                    // If it makes it past initialization, it fails here during the MAC/Tag check.
                    val decryptedBytes = cryptoObject.cipher?.doFinal(encryptedBytes)
                    result.success(String(decryptedBytes!!))
                } catch (e: Exception) {
                    // CATCH AEADBadTagException and KeyStoreException!
                    // Delete the corrupted data so the user isn't permanently locked out
                    prefs.edit().remove(key).remove("${key}_iv").apply()
                    result.error("hardware_desync", "Hardware Keystore desynchronized. Data wiped.", null)
                }
            }
        } catch (e: Exception) {
            // Catch initialization errors and wipe data
            prefs.edit().remove(key).remove("${key}_iv").apply()
            result.error("hardware_desync", "Cipher initialization failed. Data wiped.", null)
        }
    }

    // --- Biometric UI & Keystore Helpers --- //

    private fun showBiometricPrompt(title: String, cipher: Cipher, onComplete: (BiometricPrompt.CryptoObject?) -> Unit) {
        val fragmentActivity = activity ?: return onComplete(null)
        val executor = ContextCompat.getMainExecutor(context)
        
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setAllowedAuthenticators(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .setNegativeButtonText("Cancel")
            .build()

        val biometricPrompt = BiometricPrompt(fragmentActivity, executor, object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                onComplete(result.cryptoObject)
            }
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                onComplete(null)
            }
        })

        // Pass the Cipher into the CryptoObject so the hardware Keystore unlocks it!
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
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }
    override fun onDetachedFromActivity() { activity = null }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}