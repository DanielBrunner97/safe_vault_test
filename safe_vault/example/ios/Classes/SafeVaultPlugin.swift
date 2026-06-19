import Flutter
import UIKit
import LocalAuthentication

public class SafeVaultPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "safe_vault", binaryMessenger: registrar.messenger())
    let instance = SafeVaultPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let key = args["key"] as? String else {
      result(FlutterError(code: "invalid_args", message: "Missing arguments", details: nil))
      return
    }

    switch call.method {
    case "saveSecret":
        guard let secret = args["secret"] as? String else { return result(false) }
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
    guard let data = secret.data(using: .utf8) else { return false }
    
    // Create access control that REQUIRES biometrics
    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
        nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .biometryCurrentSet, &error
    ) else { return false }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
        kSecAttrAccessControl as String: accessControl
    ]

    // Delete existing first, then add new
    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  private func read(key: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecUseOperationPrompt as String: "Unlock to access your secure data"
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func delete(key: String) -> Bool {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key
    ]
    return SecItemDelete(query as CFDictionary) == errSecSuccess
  }
}