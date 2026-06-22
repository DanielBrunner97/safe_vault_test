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

        let args = call.arguments as? [String: Any]

        switch call.method {
        case "saveSecret":
            guard let key = args?["key"] as? String,
                let secret = args?["secret"] as? String else {
                result(FlutterError(code: "invalid_args", message: "Missing key or secret", details: nil))
                return
            }
            result(save(key: key, secret: secret))

        case "getSecret":
            guard let key = args?["key"] as? String else {
                result(FlutterError(code: "invalid_args", message: "Missing key", details: nil))
                return
            }
            NSLog("SAFE_VAULT: getSecret using readWithPrompt")
            
            readWithPrompt(key: key) { secret, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(error)
                    } else {
                        result(secret)
                    }
                }
            }

        case "deleteSecret":
            guard let key = args?["key"] as? String else {
                result(FlutterError(code: "invalid_args", message: "Missing key", details: nil))
                return
            }
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
                result(true)
            } else {
                if let laError = error as? LAError, laError.code == .biometryNotAvailable {
                    result(false)
                } else {
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

    private func readWithPrompt(key: String, completion: @escaping (String?, FlutterError?) -> Void) {
        NSLog("SAFE_VAULT: readWithPrompt started")

        let context = LAContext()
        context.localizedReason = "Unlock to access your secure data"
        context.touchIDAuthenticationAllowableReuseDuration = 0

        var authError: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)

        guard canEvaluate else {
            completion(nil, FlutterError(code: "no_biometrics", message: "Biometrics not available", details: nil))
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock to access your secure data") { success, error in
            if let laError = error as? LAError {
                let errorCode: String
                switch laError.code {
                case .userCancel, .appCancel, .systemCancel:
                    errorCode = "user_canceled"
                case .biometryNotAvailable, .biometryNotEnrolled:
                    errorCode = "no_biometrics"
                default:
                    errorCode = "auth_error"
                }
                
                completion(nil, FlutterError(code: errorCode, message: laError.localizedDescription, details: nil))
                return
            }

            guard success else {
                completion(nil, FlutterError(code: "auth_error", message: "Authentication failed", details: nil))
                return
            }

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

            guard status == errSecSuccess, let data = item as? Data else {
                // If it fails here, the biometrics changed OR the item never existed.
                // We return your 'hardware_desync' code so Dart can handle it safely.
                completion(nil, FlutterError(
                    code: "hardware_desync", 
                    message: "Biometric set changed or item not found. Key invalidated.", 
                    details: nil
                ))
                return
            }

            let secret = String(data: data, encoding: .utf8)
            completion(secret, nil)
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