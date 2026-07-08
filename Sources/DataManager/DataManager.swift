// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public final class DataManager {
    
    public static let shared = DataManager()
    private init() {
        config = .init()
        keychain = .init(synchronizable: true, securityLevel: .afterFirstUnlock)
        userDefaults = .standard
    }
    
    private let config: DataConfiguration
    private let keychain: KeyManager
    private let userDefaults: UserDefaults
    
    public var lastError: KeychainError? = nil
    
    public init(config: DataConfiguration) {
        self.config = config
        keychain = .init(config: config)
        userDefaults = if let suiteName = config.suiteName {
            UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            UserDefaults.standard
        }
    }
    
    public static func shared(
        suiteName: String? = nil,
        sync: Bool = false,
        securityLevel: SecurityLevel? = nil,
        bundleIdentifier: String? = nil
    ) -> DataManager {
        let config = DataConfiguration(
            suiteName: suiteName,
            isSynchronized: sync,
            securityLevel: securityLevel,
            bundleIdentifier: bundleIdentifier
        )
        let dataManager = DataManager(config: config)
        return dataManager
    }
        
    @discardableResult
    public func save<T: Codable>(_ file: String, value: T, type: SaveType = .none) -> Bool {
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(value) else { return false }
        
        switch type {
        case .none:
            userDefaults.set(data, forKey: file)
            return true
        case .secure: return secureSave(file, value: value)
        case .file: return saveToDocuments(file, value: data) != nil
        }
        
    }
    
    public func retrieve<T: Codable>(_ file: String, type: SaveType = .none) -> T? {
        switch type {
        case .none:
            guard let data = userDefaults.value(forKey: file) as? Data else {return nil}
            return try? JSONDecoder().decode(T.self, from: data)
        case .secure: return secureRetrive(file)
        case .file: return retrieveDocument(file)
        }
    }
    
    public func exist(_ file: String, type: SaveType = .none) -> Bool {
        switch type {
        case .none: return userDefaults.object(forKey: file) != nil
        case .secure: return secureExist(file)
        case .file: return existDocument(file)
        }
    }
    
    public func delete(_ file: String, type: SaveType = .none) {
        switch type {
        case .none: userDefaults.removeObject(forKey: file)
        case .secure: secureDelete(file)
        case .file: deleteDocument(file)
        }
    }
    
    
    // MARK: public file Manager
    public func existAtURL(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.absoluteString) }
    
    public func retrieveAtURL(_ url: URL) -> Data? { try? Data(contentsOf: url) }
    
    public func delete(_ url: URL) { try? FileManager.default.removeItem(at: url) }
    
    @discardableResult
    public func saveToDocuments(_ fileName: String, value: Data) -> URL? {
        let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let fileURL = docDirectory?.appendingPathComponent(fileName) else {return nil}
        do { try value.write(to: fileURL); return fileURL } catch { return nil }
    }
    
    
    // MARK: private file manager
    private func existDocument(_ fileName: String) -> Bool {
        let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let fileURL = docDirectory?.appendingPathComponent(fileName) else {return false}
        return FileManager.default.fileExists(atPath: fileURL.absoluteString)
    }
    
    private func retrieveDocument<T: Codable>(_ fileName: String) -> T? {
        let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let fileURL = docDirectory?.appendingPathComponent(fileName) else {return nil}
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    private func deleteDocument(_ fileName: String) {
        let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let fileURL = docDirectory?.appendingPathComponent(fileName) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    
    // MARK: Secure Files
    private func secureSave<T: Codable>(_ file: String, value: T) -> Bool {
        do {
            try keychain.save(key: file, value: value)
            return true
        } catch {
            if let error = error as? KeychainError {
                if case .duplicateEntry = error {
                    return secureUpdate(file, value: value)
                }
                lastError = error
            }
            return false
        }
    }
    
    private func secureExist(_ file: String) -> Bool { keychain.exists(key: file) }
    
    private func secureUpdate<T: Codable>(_ file: String, value: T) -> Bool {
        do {
            try keychain.update(key: file, value: value)
            return true
        } catch {
            if let error = error as? KeychainError {
                lastError = error
            }
            return false
        }
    }
    
    private func secureRetrive<T: Codable>(_ file: String) -> T? {
        do {
            return try keychain.retrieve(key: file)
        } catch {
            if let error = error as? KeychainError { lastError = error }
            return nil
        }
    }
    
    private func secureDelete(_ file: String) {
        do {
            try keychain.delete(key: file)
        } catch {
            if let error = error as? KeychainError { lastError = error }
        }
    }
    
}
