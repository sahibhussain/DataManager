// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import KeychainSwift

public class SHDataManager {
    
    public static let shared = SHDataManager()
    private init(){}
    
    private let keychain = KeychainSwift()
    
    public var lastError: OSStatus { keychain.lastResultCode }
    
    // MARK: UserDefaults
    public func save(_ file: String, value: String, isSecure: Bool = false) { isSecure ? secureSave(file, value: value) : UserDefaults.standard.set(value, forKey: file) }
    public func save(_ file: String, value: Bool, isSecure: Bool = false) { isSecure ? secureSave(file, value: value) : UserDefaults.standard.set(value, forKey: file) }
    public func save(_ file: String, value: Int) { UserDefaults.standard.set(value, forKey: file) }
    public func save(_ file: String, value: Double) { UserDefaults.standard.set(value, forKey: file) }
    public func save(_ file: String, value: Date) { UserDefaults.standard.set(value, forKey: file) }
    
    public func save<T: Codable>(_ file: String, value: T, isSecure: Bool = false) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        if let data = try? encoder.encode(value) {
            isSecure ? secureSave(file, value: data) : UserDefaults.standard.set(data, forKey: file)
        }
    }
    
    
    public func exist(_ file: String, isSecure: Bool = false) -> Bool {
        if isSecure { return secureExist(file) }
        return UserDefaults.standard.object(forKey: file) != nil
    }
    
    
    public func retrieve(_ file: String, isSecure: Bool = false) -> String? { isSecure ? secureRetrive(file) : UserDefaults.standard.string(forKey: file) }
    public func retrieve(_ file: String, isSecure: Bool = false) -> Bool? { isSecure ? secureRetrive(file) : UserDefaults.standard.bool(forKey: file) }
    public func retrieve(_ file: String) -> Int? { UserDefaults.standard.integer(forKey: file) }
    public func retrieve(_ file: String) -> Double? { UserDefaults.standard.double(forKey: file) }
    public func retrieve(_ file: String) -> Date? { (UserDefaults.standard.value(forKey: file) as? Date) }
    
    public func retrieve<T: Codable>(_ file: String, isSecure: Bool = false) -> T? {
        
        if isSecure { return secureRetrive<T>(file) }
        
        guard let data = UserDefaults.standard.value(forKey: file) as? Data else {return nil}
        return try? JSONDecoder().decode(T.self, from: data)
        
    }
    
    
    public func delete(_ file: String, isSecure: Bool = false) { isSecure ? secureDelete(file) : UserDefaults.standard.removeObject(forKey: file) }
    
    
    // MARK: file Manager
    public func saveToDocuments(_ fileName: String, value: Data) -> URL? {
        
        let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let fileURL = docDirectory?.appendingPathComponent(fileName) else {return nil}
        
        do {
            try value.write(to: fileURL)
            return fileURL
        } catch let error {
            print(error)
            return nil
        }
        
    }
    
    
    public func existAtURL(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.absoluteString) }
    
    public func existDocument(_ fileName: String) -> Bool {
        let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let fileURL = docDirectory?.appendingPathComponent(fileName) else {return false}
        return FileManager.default.fileExists(atPath: fileURL.absoluteString)
    }
    
    
    public func retrieveDocument(_ fileName: String) -> Data? {
        let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let fileURL = docDirectory?.appendingPathComponent(fileName) else {return nil}
        return try? Data(contentsOf: fileURL)
    }
    
    public func retrieveAtURL(_ url: URL) -> Data? { try? Data(contentsOf: url) }
    
    
    public func delete(_ url: URL) { try? FileManager.default.removeItem(at: url) }
    
    public func deleteDocument(_ fileName: String) {
        let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let fileURL = docDirectory?.appendingPathComponent(fileName) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    
    // MARK: Secure Files
    private func secureSave(_ file: String, value: String) { keychain.set(value, forKey: file) }
    private func secureSave(_ file: String, value: Bool) { keychain.set(value, forKey: file) }
    private func secureSave(_ file: String, value: Data) { keychain.set(value, forKey: file)}
    
    
    private func secureExist(_ file: String) -> Bool { keychain.getData(file) != nil }
    
    
    private func secureRetrive(_ file: String) -> String? { keychain.get(file) }
    private func secureRetrive(_ file: String) -> Bool? { keychain.getBool(file) }
    
    private func secureRetrive<T: Codable>(_ file: String) -> T? {
        guard let data = keychain.getData(file) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    
    private func secureDelete(_ file: String) { keychain.delete(file) }
    
}
