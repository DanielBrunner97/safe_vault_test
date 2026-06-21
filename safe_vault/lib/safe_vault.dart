import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:safe_vault/android_options.dart';
import 'package:safe_vault/safe_vault_platform_interface.dart';
import 'package:safe_vault/safe_vault_exceptions.dart'; // Import your new classes

class SafeVault {
  static const MethodChannel _channel = MethodChannel('safe_vault');

  /// Saves a secret behind a biometric prompt.
  ///
  /// Throws:
  /// * [VaultUserCanceledException] if the user dismisses the biometric prompt.
  /// * [VaultNoBiometricsException] if the device does not have biometrics hardware or it is not enrolled.
  /// * [VaultAuthException] if biometric authentication fails natively.
  /// * [VaultUnknownException] for any other unmapped native errors.
  Future<bool> saveSecret({
    required String key,
    required String secret,
    AndroidOptions androidOptions = const AndroidOptions(
      title: 'Authenticate to secure your data',
    ),
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('saveSecret', {
        'key': key,
        'secret': secret,
        ...androidOptions.toMap(),
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw SafeVaultException.fromPlatform(e.code, e.message);
    }
  }

  /// Retrieves a secret behind a biometric prompt.
  ///
  /// Throws:
  /// * [VaultUserCanceledException] if the user dismisses the biometric prompt.
  /// * [VaultNoBiometricsException] if the device does not have biometrics hardware or it is not enrolled.
  /// * [VaultAuthException] if biometric authentication fails natively.
  /// * [VaultHardwareDesyncException] if the OS wipes the secure keys (e.g., user added a new fingerprint).
  /// * [VaultUnknownException] for any other unmapped native errors.
  Future<String?> getSecret({
    required String key,
    AndroidOptions androidOptions = const AndroidOptions(
      title: 'Unlock your secure data',
    ),
  }) async {
    try {
      return await _channel.invokeMethod<String>('getSecret', {
        'key': key,
        ...androidOptions.toMap(),
      });
    } on PlatformException catch (e) {
      if (e.code == 'hardware_desync') {
        debugPrint('Vault corrupted by OS. Data was wiped safely.');
      }
      throw SafeVaultException.fromPlatform(e.code, e.message);
    }
  }

  /// Deletes the secret.
  ///
  /// Throws a [SafeVaultException] (usually a [VaultUnknownException])
  /// if the underlying native keychain/keystore fails to delete the item.
  Future<bool> deleteSecret({required String key}) async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteSecret', {
        'key': key,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw SafeVaultException.fromPlatform(e.code, e.message);
    }
  }

  /// Checks if biometric authentication is available on the device.
  ///
  /// Does not throw. Returns `false` if an error occurs.
  Future<bool> isBiometricAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isBiometricAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking biometric availability: ${e.message}');
      return false; // Safely assume false for boolean checks
    }
  }

  /// Checks if the device is supported (has biometric hardware).
  ///
  /// Does not throw. Returns `false` if an error occurs.
  Future<bool> isDeviceSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceSupported');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Retrieves the host platform version.
  Future<String?> getPlatformVersion() {
    return SafeVaultPlatform.instance.getPlatformVersion();
  }
}
