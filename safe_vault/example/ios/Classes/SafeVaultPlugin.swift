import Flutter
import UIKit
import LocalAuthentication

public class SafeVaultPlugin: NSObject, FlutterPlugin {
    private let service = "safe_vault"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "safe_vault",
            binaryMessenger: registrar.messenger()
        )

        let instance = SafeVaultPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let key = args["key"] as? String else {
            result(FlutterError(code: "invalid_args", message: "Missing arguments", details: nil))
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
            result(read(key: key))

        case "deleteSecret":
            result(delete(key: key))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func save(key: String, secret: String) -> Bool {
        guard let data = secret.data(using: .utf8) else {
            return false
        }

        var error: Unmanaged<CFError>?

        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            print("Access control error:", String(describing: error))
            return false
        }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        print("Keychain save status:", status)

        return status == errSecSuccess
    }

    private func read(key: String) -> String? {
        let context = LAContext()
        context.localizedReason = "Unlock to access your secure data"

        // Prevent reuse of a recent biometric auth as much as possible.
        context.touchIDAuthenticationAllowableReuseDuration = 0

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        print("Keychain read status:", status)

        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        print("Keychain delete status:", status)

        return status == errSecSuccess || status == errSecItemNotFound
    }
}