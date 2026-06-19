import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'safe_vault_method_channel.dart';

abstract class SafeVaultPlatform extends PlatformInterface {
  /// Constructs a SafeVaultPlatform.
  SafeVaultPlatform() : super(token: _token);

  static final Object _token = Object();

  static SafeVaultPlatform _instance = MethodChannelSafeVault();

  /// The default instance of [SafeVaultPlatform] to use.
  ///
  /// Defaults to [MethodChannelSafeVault].
  static SafeVaultPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SafeVaultPlatform] when
  /// they register themselves.
  static set instance(SafeVaultPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
