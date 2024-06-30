// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import KeychainSwift

public class SHDataManager {
    
    public static let shared = SHDataManager()
    private init() { keychain.synchronizable = true }
    
    private let keychain = KeychainSwift()
    
    public var lastError: OSStatus { keychain.lastResultCode }
        
    @discardableResult
    public func save<T: Codable>(_ file: String, value: T, isSecure: Bool = false, isFile: Bool = false) -> Bool {
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(value) else { return false }
        
        if isFile { return saveToDocuments(file, value: data) != nil }
        
        isSecure ? secureSave(file, value: data) : UserDefaults.standard.set(data, forKey: file)
        return true
        
    }
    
    public func retrieve<T: Codable>(_ file: String, isSecure: Bool = false, isFile: Bool) -> T? {
        
        if isSecure {
            let secureValue: T? = secureRetrive(file)
            return secureValue
        }
        
        if isFile {
            let docValue: T? = retrieveDocument(file)
            return docValue
        }
        
        guard let data = UserDefaults.standard.value(forKey: file) as? Data else {return nil}
        return try? JSONDecoder().decode(T.self, from: data)
        
    }
    
    public func exist(_ file: String, isSecure: Bool = false, isFile: Bool = false) -> Bool {
        if isFile { return existDocument(file) }
        if isSecure { return secureExist(file) }
        return UserDefaults.standard.object(forKey: file) != nil
    }
    
    public func delete(_ file: String, isSecure: Bool = false, isFile: Bool = false) {
        if isFile { deleteDocument(file); return }
        isSecure ? secureDelete(file) : UserDefaults.standard.removeObject(forKey: file)
    }
    
    
    // MARK: public file Manager
    public func existAtURL(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.absoluteString) }
    
    public func retrieveAtURL(_ url: URL) -> Data? { try? Data(contentsOf: url) }
    
    public func delete(_ url: URL) { try? FileManager.default.removeItem(at: url) }
    
    @discardableResult
    public func saveToDocuments(_ fileName: String, value: Data) -> URL? {
        let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let fileURL = docDirectory?.appendingPathComponent(fileName) else {return nil}
        do { try value.write(to: fileURL); return fileURL } catch let error { return nil }
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
    private func secureSave(_ file: String, value: Data) { keychain.set(value, forKey: file) }
    
    private func secureExist(_ file: String) -> Bool { keychain.getData(file) != nil }
    
    private func secureRetrive<T: Codable>(_ file: String) -> T? {
        guard let data = keychain.getData(file) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    private func secureDelete(_ file: String) { keychain.delete(file) }
    
}
