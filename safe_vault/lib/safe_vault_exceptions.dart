/// The base exception for all Safe Vault errors.
sealed class SafeVaultException implements Exception {
  final String message;

  SafeVaultException(this.message);

  /// Factory constructor to map native PlatformExceptions to our sealed classes.
  factory SafeVaultException.fromPlatform(String code, String? message) {
    final msg = message ?? 'Unknown vault error occurred';
    switch (code) {
      case 'user_canceled':
        return VaultUserCanceledException(msg);
      case 'no_biometrics':
        return VaultNoBiometricsException(msg);
      case 'auth_error':
        return VaultAuthException(msg);
      case 'hardware_desync':
        return VaultHardwareDesyncException(msg);
      default:
        return VaultUnknownException(msg);
    }
  }

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the user dismisses the biometric prompt.
class VaultUserCanceledException extends SafeVaultException {
  VaultUserCanceledException(super.message);
}

/// Thrown when the device does not have biometrics hardware or it is not enrolled.
class VaultNoBiometricsException extends SafeVaultException {
  VaultNoBiometricsException(super.message);
}

/// Thrown when biometric authentication fails natively.
class VaultAuthException extends SafeVaultException {
  VaultAuthException(super.message);
}

/// Thrown when the OS wipes the secure keys (e.g., user added a new fingerprint).
class VaultHardwareDesyncException extends SafeVaultException {
  VaultHardwareDesyncException(super.message);
}

/// Thrown for any other unmapped native errors.
class VaultUnknownException extends SafeVaultException {
  VaultUnknownException(super.message);
}
