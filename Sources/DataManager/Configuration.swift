//
//  Configuration.swift
//  DataManager
//
//  Created by Sahib hussain on 08/07/26.
//
import Foundation

public enum SaveType {
    case none, secure, file
}

public enum KeychainError: LocalizedError {
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

public struct DataConfiguration {
    
    var suiteName: String?
    var isSynchronized: Bool
    var securityLevel: SecurityLevel?
    var bundleIdentifier: String?
    
    init(
        suiteName: String? = nil,
        isSynchronized: Bool = false,
        securityLevel: SecurityLevel? = nil,
        bundleIdentifier: String? = nil
    ) {
        self.suiteName = suiteName
        self.isSynchronized = isSynchronized
        self.securityLevel = securityLevel
        self.bundleIdentifier = bundleIdentifier
    }
    
}
