package com.example.secure_files_application

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.security.keystore.UserNotAuthenticatedException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Wraps small secrets with non-exportable AES-256-GCM keys that live in the
 * Android Keystore (TEE, or StrongBox when the device has one). The raw key
 * never reaches app memory; only encrypt/decrypt calls cross into secure
 * hardware.
 *
 * Wire format of a wrapped value: ivLength (1 byte) | iv | ciphertext+tag.
 */
object KeystoreChannel : MethodChannel.MethodCallHandler {
    private const val PROVIDER = "AndroidKeyStore"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val TAG_BITS = 128

    /** Seconds a biometric-bound key stays usable after a fingerprint check. */
    private const val AUTH_VALIDITY_SECONDS = 15

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val alias = call.argument<String>("alias")
                ?: return result.error("BAD_ARGS", "alias missing", null)
            when (call.method) {
                "wrap" -> {
                    val data = call.argument<ByteArray>("data")
                        ?: return result.error("BAD_ARGS", "data missing", null)
                    val requireAuth = call.argument<Boolean>("requireAuth") ?: false
                    result.success(wrap(alias, data, requireAuth))
                }
                "unwrap" -> {
                    val data = call.argument<ByteArray>("data")
                        ?: return result.error("BAD_ARGS", "data missing", null)
                    result.success(unwrap(alias, data))
                }
                "delete" -> {
                    keyStore().deleteEntry(alias)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            result.error("KEY_INVALIDATED", null, null)
        } catch (e: UserNotAuthenticatedException) {
            result.error("AUTH_REQUIRED", null, null)
        } catch (e: AEADBadTagException) {
            result.error("BAD_DATA", null, null)
        } catch (e: Exception) {
            // Never send key material or data in error messages.
            result.error("KEYSTORE_ERROR", e.javaClass.simpleName, null)
        }
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(PROVIDER).apply { load(null) }

    private fun existingKey(alias: String): SecretKey? =
        keyStore().getKey(alias, null) as? SecretKey

    private fun getOrCreateKey(alias: String, requireAuth: Boolean): SecretKey {
        existingKey(alias)?.let { return it }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                return generateKey(alias, requireAuth, strongBox = true)
            } catch (e: StrongBoxUnavailableException) {
                // Fall through to the TEE-backed key.
            }
        }
        return generateKey(alias, requireAuth, strongBox = false)
    }

    private fun generateKey(alias: String, requireAuth: Boolean, strongBox: Boolean): SecretKey {
        val spec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)

        if (requireAuth) {
            spec.setUserAuthenticationRequired(true)
            // New fingerprints destroy the key, so someone who adds their
            // own finger to an unlocked phone cannot open the vault with it.
            spec.setInvalidatedByBiometricEnrollment(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                spec.setUserAuthenticationParameters(
                    AUTH_VALIDITY_SECONDS,
                    KeyProperties.AUTH_BIOMETRIC_STRONG,
                )
            } else {
                @Suppress("DEPRECATION")
                spec.setUserAuthenticationValidityDurationSeconds(AUTH_VALIDITY_SECONDS)
            }
        }
        if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            spec.setIsStrongBoxBacked(true)
        }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, PROVIDER)
        generator.init(spec.build())
        return generator.generateKey()
    }

    private fun wrap(alias: String, data: ByteArray, requireAuth: Boolean): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        // The Keystore picks a fresh random IV for every encryption.
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey(alias, requireAuth))
        val iv = cipher.iv
        val sealed = cipher.doFinal(data)
        return byteArrayOf(iv.size.toByte()) + iv + sealed
    }

    private fun unwrap(alias: String, data: ByteArray): ByteArray {
        val key = existingKey(alias) ?: throw IllegalStateException("No key")
        val ivLength = data[0].toInt()
        require(ivLength in 12..16 && data.size > 1 + ivLength) { "Malformed" }
        val iv = data.copyOfRange(1, 1 + ivLength)
        val sealed = data.copyOfRange(1 + ivLength, data.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, iv))
        return cipher.doFinal(sealed)
    }
}
