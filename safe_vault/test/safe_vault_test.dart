import 'package:flutter_test/flutter_test.dart';
import 'package:safe_vault/safe_vault.dart';
import 'package:safe_vault/safe_vault_platform_interface.dart';
import 'package:safe_vault/safe_vault_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSafeVaultPlatform
    with MockPlatformInterfaceMixin
    implements SafeVaultPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SafeVaultPlatform initialPlatform = SafeVaultPlatform.instance;

  test('$MethodChannelSafeVault is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSafeVault>());
  });

  test('getPlatformVersion', () async {
    SafeVault safeVaultPlugin = SafeVault();
    MockSafeVaultPlatform fakePlatform = MockSafeVaultPlatform();
    SafeVaultPlatform.instance = fakePlatform;

    expect(await safeVaultPlugin.getPlatformVersion(), '42');
  });
}
