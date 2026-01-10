//
//  SHKeyManager.swift
//  SHNetwork
//
//  Created by sahib hussain on 08/06/18.
//  Copyright © 2018 Burning Desire Inclusive. All rights reserved.
//

import Foundation
import Security

public final class KeyManager {

    public enum KeyError: LocalizedError {
        case invalidData
        case duplicateEntry
        case itemNotFound
        case unexpectedData
        case keyGenerationFailed
        case unknown(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .invalidData:
                return "Data is invalid or cannot be encoded."
            case .duplicateEntry:
                return "Keychain item already exists."
            case .itemNotFound:
                return "Requested item was not found in the Keychain."
            case .unexpectedData:
                return "Unexpected data returned from the Keychain."
            case .keyGenerationFailed:
                return "Failed to generate cryptographic keypair."
            case .unknown(let status):
                return SecCopyErrorMessageString(status, nil) as String? ??
                       "Unknown Keychain error: \(status)"
            }
        }
    }
    
    public enum SecurityLevel {
        
        case afterFirstUnlock, afterEveryUnlock
        
        var value: CFString {
            switch self {
            case .afterFirstUnlock: return kSecAttrAccessibleAfterFirstUnlock
            case .afterEveryUnlock: return kSecAttrAccessibleWhenUnlocked
            }
        }
        
    }

    public static let shared = KeyManager()
    private init() {}
    
    private let domain = Bundle.main.bundleIdentifier ?? "com.burningdesireinclusive.SHNetwork"
    
    public var accessGroup: String? = nil
    public var synchronizable: Bool = true
    public var securityLevel: SecurityLevel = .afterFirstUnlock
    
    
    private func commonQuery(forKey key: String) -> [String: Any] {
        var q: [String : Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: domain,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: securityLevel.value
        ]
        if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
        if synchronizable { q[kSecAttrSynchronizable as String] = kCFBooleanTrue }
        return q
    }

    
    public func save<T: Codable>(key: String, value: T) throws {

        guard let data = try? JSONEncoder().encode(value) else {
            throw KeyError.invalidData
        }

        var query = commonQuery(forKey: key)
        query[kSecValueData as String] = data
        
        let status = SecItemAdd(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            throw KeyError.duplicateEntry
        default:
            throw KeyError.unknown(status)
        }
    }

    public func retrieve<T: Codable>(key: String) throws -> T? {

        var query = commonQuery(forKey: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound { return nil }
            throw KeyError.unknown(status)
        }

        guard
            let data = result as? Data,
            let value = try? JSONDecoder().decode(T.self, from: data)
        else { throw KeyError.unexpectedData }
        return value
        
    }

    public func update<T: Codable>(key: String, value: T) throws {

        guard let data = try? JSONEncoder().encode(value) else { throw KeyError.invalidData }

        let query = commonQuery(forKey: key)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else { throw KeyError.unknown(status) }
        
    }
    
    public func exists(key: String) -> Bool {
        
        var query = commonQuery(forKey: key)
        query[kSecReturnData as String] = kCFBooleanFalse
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
        
    }

    public func delete(key: String) throws {
        let query = commonQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeyError.unknown(status) }
    }

    
    public func generateKeypair(tag: String, keySize: Int = 2048) throws -> (privateKey: String, publicKey: String) {

        let privateTag = "\(tag).private".data(using: .utf8)!
        let publicTag  = "\(tag).public".data(using: .utf8)!

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: keySize,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: privateTag
            ],
            kSecPublicKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: publicTag
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw KeyError.keyGenerationFailed
        }

        guard
            let privateData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data?,
            let publicData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data?
        else {
            throw KeyError.keyGenerationFailed
        }

        return (
            privateKey: privateData.base64EncodedString(),
            publicKey: publicData.base64EncodedString()
        )
    }
    
}

