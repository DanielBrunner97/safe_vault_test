# safe_vault

A highly secure, lightweight Flutter plugin for hardware-backed biometric encryption. 

Unlike generalized storage packages that carry architectural bloat, `safe_vault` interacts directly with native security layers—**iOS LocalAuthentication / Keychain** and **Android BiometricPrompt / Keystore (TEE)**. It is specifically hardened against Android OEM fragmentation and Keystore desynchronization bugs.

## Key Features

* **Hardware-Backed AES-GCM:** Encrypts data using a unique key generated natively in hardware.
* **Biometric Interlocking:** Cryptographic operations are coupled directly to biometric evaluation.
* **Anti-Crash Recovery (OEM Desync Safety):** Catches hardware panics (like the infamous Xiaomi `AEADBadTagException`) gracefully, wiping corrupted state smoothly instead of crashing the application runtime.
* **StrongBox Exclusion:** Intentionally utilizes the stable **TEE (Trusted Execution Environment)** rather than buggy OEM StrongBox implementations to eliminate random `-30 KeystoreOperation` execution panics.
* **Zero Bloat:** Minimal footprint, bypassing the legacy dependencies of public storage wrappers.

---

## Installation

Add this to your internal project's `pubspec.yaml`:

```yaml
dependencies:
  safe_vault:
    path: ../safe_vault # Or git URL repository matching your path layout
```

### Platform Setup

#### **Android**
Ensure your app's `android/app/src/main/AndroidManifest.xml` includes the necessary biometric permissions within the `<manifest>` tag:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
```

#### **iOS**
Add the `NSFaceIDUsageDescription` key to your `ios/Runner/Info.plist` file to explain why your app requires authentication capabilities:

```xml
<key>NSFaceIDUsageDescription</key>
<string>This app requires Face ID to securely authenticate and decrypt your vault data.</string>
```

---

## Usage Guide

Initialize the plugin instance within your codebase:

```dart
final SafeVault _safeVault = SafeVault();
```

### Hardware Capability Checks

Always check hardware realities prior to attempting encryption or offering user configuration setups:

```dart
// 1. Verify if physical scanner hardware exists on the device
bool hardwareExists = await _safeVault.isDeviceSupported();

// 2. Verify if the user has actually enrolled biometric records (Fingerprints/Face)
bool isEnrolled = await _safeVault.isBiometricAvailable();
```

### Saving a Secret

Encrypt data using a unique identifier. This triggers a biometric prompt to authorize the initialization key writing event:

```dart
try {
  bool isSaved = await _safeVault.saveSecret(
    key: 'auth_token',
    secret: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    androidOptions: const AndroidOptions(
      title: 'Authorize Secure Storage',
      subtitle: 'Scan your fingerprint to encrypt your session key.',
    ),
  );
  
  if (isSaved) {
    // Secret safely isolated in native hardware
  }
} on SafeVaultException catch (e) {
  print('Failed to write secret: ${e.message} (Code: ${e.code})');
}
```

### Reading a Secret

Retrieve and decrypt data securely. This requires a biometric interaction to free up the hardware key sequence:

```dart
try {
  String? secret = await _safeVault.getSecret(
    key: 'auth_token',
    androidOptions: const AndroidOptions(
      title: 'Unlock Session Data',
    ),
  );

  if (secret != null) {
    // Proceed with your sensitive operations (e.g., Keycloak API calls)
  } else {
    // Key missing
  }
} on SafeVaultException catch (e) {
  if (e.code == 'hardware_desync') {
    // Wiped cleanly from SharedPreferences on error.
    // Seamlessly prompt your user to re-authenticate via Keycloak login.
    print('Hardware Keystore panic caught and cleared safely.');
  } else {
    print('Failed to decrypt data: ${e.message}');
  }
}
```

### Deleting a Secret

Purge keys manually when a user logs out:

```dart
bool deleted = await _safeVault.deleteSecret(key: 'auth_token');
```

---