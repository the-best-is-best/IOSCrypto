//
//  IOSCrypto.swift
//  IOSCrypto
//
//  Created by Michelle Raouf on 02/03/2025.
//

import Foundation

@objc public class IOSCryptoManager : NSObject {
    
    @objc public enum KeychainError: Int, Error {
        case unknown = -1
        case noData = 1
        case unexpectedData = 2

        public func description() -> String {
            switch self {
            case .unknown: return "Unknown error"
            case .noData: return "No data found"
            case .unexpectedData: return "Unexpected data found"
            }
        }

        public var asNSError: NSError {
            return NSError(domain: "IOSCrypto.Keychain", code: self.rawValue, userInfo: [NSLocalizedDescriptionKey: self.description()])
        }
    }

    // MARK: - Objective-C Compatible Completion Handlers
    @objc public static func save(
        service: String,
        account: String,
        data: String,
        completion: @escaping (NSError?) -> Void
    ) {
        guard let dataAsData = data.data(using: .utf8) else {
            completion(KeychainError.unknown.asNSError)
            return
        }

        saveDataType(service: service, account: account, data: dataAsData, completion: completion)
    }

    @objc public static func saveDataType(
        service: String,
        account: String,
        data: Data,
        completion: @escaping (NSError?) -> Void
    ) {
        let query: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject
        ]

        let attributesToUpdate: [String: AnyObject] = [
            kSecValueData as String: data as AnyObject
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        if status == errSecItemNotFound {
            var newQuery = query
            newQuery[kSecValueData as String] = data as AnyObject
            let addStatus = SecItemAdd(newQuery as CFDictionary, nil)

            if addStatus != errSecSuccess {
                completion(KeychainError.unknown.asNSError)
            } else {
                completion(nil)
            }
        } else if status != errSecSuccess {
            completion(KeychainError.unknown.asNSError)
        } else {
            completion(nil)
        }
    }

    @objc public static func get(
        service: String,
        account: String,
        completion: @escaping (NSString?, NSError?) -> Void
    ) {
        do {
            let data = try retrieveData(service: service, account: account)
            let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            completion(string, nil)
        } catch let error as KeychainError {
            completion(nil, error.asNSError)
        } catch {
            completion(nil, KeychainError.unknown.asNSError)
        }
    }

    @objc public static func getDataType(
        service: String,
        account: String,
        completion: @escaping (NSData?, NSError?) -> Void
    ) {
        do {
            let data = try retrieveData(service: service, account: account)
            completion(data as NSData, nil)
        } catch let error as KeychainError {
            completion(nil, error.asNSError)
        } catch {
            completion(nil, KeychainError.unknown.asNSError)
        }
    }

    private static func retrieveData(service: String, account: String) throws -> Data {
        let query: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecReturnData as String: kCFBooleanTrue,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainError.unexpectedData
            }
            return data
        case errSecItemNotFound:
            throw KeychainError.noData
        default:
            throw KeychainError.unknown
        }
    }

    @objc public static func deleteData(service: String, account: String) {
        let query: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject
        ]
        SecItemDelete(query as CFDictionary)
    }
}
