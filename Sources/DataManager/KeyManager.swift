//
//  SHKeyManager.swift
//  SHNetwork
//
//  Created by sahib hussain on 08/06/18.
//  Copyright © 2018 Burning Desire Inclusive. All rights reserved.
//

import Foundation
import Security

final class KeyManager {
    
    private let domain: String
    private let accessGroup: String?
    private let synchronizable: Bool
    private let securityLevel: SecurityLevel
    
    init(domain: String? = nil, accessGroup: String? = nil, synchronizable: Bool, securityLevel: SecurityLevel) {
        self.domain = domain ?? Bundle.main.bundleIdentifier ?? "com.burningdesireinclusive.SHNetwork"
        self.accessGroup = accessGroup
        self.synchronizable = synchronizable
        self.securityLevel = securityLevel
    }
    
    init(config: DataConfiguration) {
        self.domain = config.bundleIdentifier ?? Bundle.main.bundleIdentifier ?? "com.burningdesireinclusive.SHNetwork"
        self.accessGroup = config.suiteName
        self.synchronizable = config.isSynchronized
        self.securityLevel = config.securityLevel ?? .afterFirstUnlock
    }
    
    
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
            throw KeychainError.invalidData
        }

        var query = commonQuery(forKey: key)
        query[kSecValueData as String] = data
        
        let status = SecItemAdd(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            throw KeychainError.duplicateEntry
        default:
            throw KeychainError.unknown(status)
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
            throw KeychainError.unknown(status)
        }

        guard
            let data = result as? Data,
            let value = try? JSONDecoder().decode(T.self, from: data)
        else { throw KeychainError.unexpectedData }
        return value
        
    }

    public func update<T: Codable>(key: String, value: T) throws {

        guard let data = try? JSONEncoder().encode(value) else { throw KeychainError.invalidData }

        let query = commonQuery(forKey: key)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else { throw KeychainError.unknown(status) }
        
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
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unknown(status) }
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
            throw KeychainError.keyGenerationFailed
        }

        guard
            let privateData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data?,
            let publicData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data?
        else {
            throw KeychainError.keyGenerationFailed
        }

        return (
            privateKey: privateData.base64EncodedString(),
            publicKey: publicData.base64EncodedString()
        )
    }
    
}

