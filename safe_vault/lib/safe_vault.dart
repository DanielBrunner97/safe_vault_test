import 'package:flutter/services.dart';
import 'package:safe_vault/android_options.dart';
import 'package:safe_vault/safe_vault_platform_interface.dart';

class SafeVault {
  static const MethodChannel _channel = MethodChannel('safe_vault');

  /// Saves a secret behind a biometric prompt.
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
        ...androidOptions.toMap(), // Spread the map
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Retrieves a secret behind a biometric prompt.
  Future<String?> getSecret({
    required String key,
    AndroidOptions androidOptions = const AndroidOptions(
      title: 'Unlock your secure data',
    ),
  }) async {
    try {
      return await _channel.invokeMethod<String>('getSecret', {
        'key': key,
        ...androidOptions.toMap(), // Spread the map
      });
    } on PlatformException catch (e) {
      if (e.code == 'hardware_desync') {
        print('Vault corrupted by OS. Data was wiped safely.');
      }
      return null;
    }
  }

  /// Deletes the secret.
  Future<bool> deleteSecret({required String key}) async {
    final result = await _channel.invokeMethod<bool>('deleteSecret', {
      'key': key,
    });
    return result ?? false;
  }

  /// Checks if biometric authentication is available on the device.
  Future<bool> isBiometricAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isBiometricAvailable');
      return result ?? false;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false; // If anything goes wrong, safely assume false
    }
  }

  /// Checks if the device is supported (has biometric hardware and OS support).
  Future<bool> isDeviceSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceSupported');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getPlatformVersion() {
    return SafeVaultPlatform.instance.getPlatformVersion();
  }
}
