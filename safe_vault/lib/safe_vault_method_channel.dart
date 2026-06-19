import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'safe_vault_platform_interface.dart';

/// An implementation of [SafeVaultPlatform] that uses method channels.
class MethodChannelSafeVault extends SafeVaultPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('safe_vault');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
