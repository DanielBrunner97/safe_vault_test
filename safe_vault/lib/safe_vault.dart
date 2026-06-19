import 'package:flutter/services.dart';
import 'package:safe_vault/safe_vault_platform_interface.dart';

class SafeVault {
  static const MethodChannel _channel = MethodChannel('safe_vault');

  /// Saves a secret behind a biometric prompt.
  Future<bool> saveSecret({required String key, required String secret}) async {
    try {
      final result = await _channel.invokeMethod<bool>('saveSecret', {
        'key': key,
        'secret': secret,
      });
      return result ?? false;
    } catch (e) {
      return false; // Or rethrow a custom exception
    }
  }

  /// Retrieves a secret behind a biometric prompt.
  /// Returns null if the user cancels, fails, or if the Xiaomi bug wipes the data.
  Future<String?> getSecret({required String key}) async {
    try {
      return await _channel.invokeMethod<String>('getSecret', {'key': key});
    } on PlatformException catch (e) {
      if (e.code == 'hardware_desync') {
        // This is our custom error catching the Xiaomi Keystore crash!
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

  Future<String?> getPlatformVersion() {
    return SafeVaultPlatform.instance.getPlatformVersion();
  }
}
