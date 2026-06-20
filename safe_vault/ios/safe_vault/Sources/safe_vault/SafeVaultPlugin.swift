import Flutter
import UIKit
import LocalAuthentication

public class SafeVaultPlugin: NSObject, FlutterPlugin {
    private let service = "safe_vault"

    public static func register(with registrar: FlutterPluginRegistrar) {
        NSLog("SAFE_VAULT: plugin registered")

        let channel = FlutterMethodChannel(
            name: "safe_vault",
            binaryMessenger: registrar.messenger()
        )

        let instance = SafeVaultPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NSLog("SAFE_VAULT: method called: \(call.method)")

        guard let args = call.arguments as? [String: Any],
              let key = args["key"] as? String else {
            result(FlutterError(
                code: "invalid_args",
                message: "Missing arguments",
                details: nil
            ))
            return
        }

        switch call.method {
        case "saveSecret":
            guard let secret = args["secret"] as? String else {
                result(false)
                return
            }

            result(save(key: key, secret: secret))

        case "getSecret":
            NSLog("SAFE_VAULT: getSecret using readWithPrompt")

            readWithPrompt(key: key) { secret in
                DispatchQueue.main.async {
                    result(secret)
                }
            }

        case "deleteSecret":
            result(delete(key: key))

        case "isBiometricAvailable":
            let context = LAContext()
            var error: NSError?
            let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            result(canEvaluate)

        case "isDeviceSupported":
            let context = LAContext()
            var error: NSError?
            let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            
            if canEvaluate {
                // It evaluated successfully, so the hardware exists and is ready
                result(true)
            } else {
                // It failed. Let's check WHY it failed.
                if let laError = error as? LAError, laError.code == .biometryNotAvailable {
                    // The device physically does not have Face ID / Touch ID
                    result(false)
                } else {
                    // It failed for another reason (e.g., biometryNotEnrolled, biometryLockout)
                    // This means the physical hardware DOES exist.
                    result(true)
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func save(key: String, secret: String) -> Bool {
        NSLog("SAFE_VAULT: save started")

        guard let data = secret.data(using: .utf8) else {
            NSLog("SAFE_VAULT: failed to convert secret to data")
            return false
        }

        var error: Unmanaged<CFError>?

        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            NSLog("SAFE_VAULT: access control error: \(String(describing: error))")
            return false
        }

        // Delete old item with service.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        NSLog("SAFE_VAULT: delete existing item status: \(deleteStatus)")

        // Optional cleanup for old items saved before you added kSecAttrService.
        let oldDeleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let oldDeleteStatus = SecItemDelete(oldDeleteQuery as CFDictionary)
        NSLog("SAFE_VAULT: delete old no-service item status: \(oldDeleteStatus)")

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        NSLog("SAFE_VAULT: keychain save status: \(status)")

        return status == errSecSuccess
    }

    private func readWithPrompt(key: String, completion: @escaping (String?) -> Void) {
        NSLog("SAFE_VAULT: readWithPrompt started")

        let context = LAContext()
        context.localizedReason = "Unlock to access your secure data"

        // Try to prevent reuse of recent Face ID auth.
        context.touchIDAuthenticationAllowableReuseDuration = 0

        var authError: NSError?

        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &authError
        )

        NSLog("SAFE_VAULT: canEvaluatePolicy: \(canEvaluate)")
        NSLog("SAFE_VAULT: authError: \(String(describing: authError))")

        guard canEvaluate else {
            completion(nil)
            return
        }

        NSLog("SAFE_VAULT: about to call evaluatePolicy")

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock to access your secure data"
        ) { success, error in
            NSLog("SAFE_VAULT: evaluatePolicy callback")
            NSLog("SAFE_VAULT: biometric success: \(success)")
            NSLog("SAFE_VAULT: biometric error: \(String(describing: error))")

            guard success else {
                completion(nil)
                return
            }

            NSLog("SAFE_VAULT: about to read keychain")

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationContext as String: context,
                kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow
            ]

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)

            NSLog("SAFE_VAULT: keychain read status: \(status)")

            guard status == errSecSuccess,
                  let data = item as? Data else {
                completion(nil)
                return
            }

            let secret = String(data: data, encoding: .utf8)
            completion(secret)
        }
    }

    private func delete(key: String) -> Bool {
        NSLog("SAFE_VAULT: delete started")

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        NSLog("SAFE_VAULT: keychain delete status: \(status)")

        return status == errSecSuccess || status == errSecItemNotFound
    }
}