// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public class DataManager {
    
    public enum SaveType {
        case none, secure, file
    }
    
    public static let shared = DataManager()
    private init() { }
    
    private let keychain = KeyManager.shared
    private var userDefaults: UserDefaults = .standard
    
    private var suiteName: String? = nil {
        didSet {
            keychain.accessGroup = suiteName
            userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        }
    }
    private var isSynchronized: Bool = false {
        didSet {
            keychain.synchronizable = isSynchronized
        }
    }
    private var securityLevel: KeyManager.SecurityLevel? = nil {
        didSet {
            keychain.securityLevel = securityLevel ?? .afterFirstUnlock
        }
    }
    
    
    public var lastError: KeyManager.KeyError? = nil
    
    public static func shared(suiteName: String? = nil, sync: Bool = false, securityLevel: KeyManager.SecurityLevel? = nil) -> DataManager {
        let dataManager = DataManager()
        dataManager.suiteName = suiteName
        dataManager.isSynchronized = sync
        dataManager.securityLevel = securityLevel
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
            if let error = error as? KeyManager.KeyError { lastError = error }
            return false
        }
    }
    
    private func secureExist(_ file: String) -> Bool { keychain.exists(key: file) }
    
    private func secureRetrive<T: Codable>(_ file: String) -> T? {
        do {
            return try keychain.retrieve(key: file)
        } catch {
            if let error = error as? KeyManager.KeyError { lastError = error }
            return nil
        }
    }
    
    private func secureDelete(_ file: String) {
        do {
            try keychain.delete(key: file)
        } catch {
            if let error = error as? KeyManager.KeyError { lastError = error }
        }
    }
    
}
