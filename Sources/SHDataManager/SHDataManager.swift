// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import KeychainAccess

public class SHDataManager {
    
    public static let shared = SHDataManager()
    private init(){}
    
    private var appBundle: String = ""
    
    public func initialise(_ bundleID: String) {
        appBundle = bundleID
    }
    
    // MARK: UserDefaults
    public func save(_ file: String, value: Any, isSecure: Bool = false) {
        
        if let str = value as? String, isSecure { secureSave(file, value: str); return }
        
        if let arrayValue = value as? [[String: Any?]] {
            var finalValue: [[String: Any]] = []
            for item in arrayValue {
                var temp: [String: Any] = [:]
                for (itemKey, itemValue) in item {
                    if let stringValue = itemValue as? String {
                        temp[itemKey] = stringValue
                    }
                    if let numValue = itemValue as? NSNumber {
                        temp[itemKey] = numValue
                    }
                }
                finalValue.append(temp)
            }
            UserDefaults.standard.set(finalValue, forKey: file)
            return
        }
        
        if let dictValue = value as? [String: Any?] {
            var finalValue: [String: Any] = [:]
            for (key, value) in dictValue {
                if dictValue[key] != nil {
                    finalValue[key] = value
                }
            }
            UserDefaults.standard.set(finalValue, forKey: file)
            return
        }
        
        UserDefaults.standard.set(value, forKey: file)
        
    }
    
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
    
    
    public func retrieve(_ file: String, isSecure: Bool = false) -> Any? { isSecure ? secureRetrive(file) : UserDefaults.standard.value(forKey: file) }
    
    public func retrieve<T: Codable>(_ file: String, isSecure: Bool = false) -> T? {
        guard let data = UserDefaults.standard.value(forKey: file) as? Data else {return nil}
        return isSecure ? secureRetrive<T>(file) : try? JSONDecoder().decode(T.self, from: data)
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
    
    
    // MARK: Secure Files
    private func secureSave(_ file: String, value: String) {
        let keychain = Keychain(service: appBundle)
        try? keychain.set(value, key: file)
    }
    
    private func secureSave(_ file: String, value: Data) {
        let keychain = Keychain(service: appBundle)
        try? keychain.set(value, key: file)
    }
    
    
    private func secureExist(_ file: String) -> Bool {
        let keychain = Keychain(service: appBundle)
        let val = keychain[data: file]
        return val != nil
    }
    
    
    private func secureRetrive(_ file: String) -> String? {
        let keychain = Keychain(service: appBundle)
        return keychain[string: file]
    }
    
    private func secureRetrive<T: Codable>(_ file: String) -> T? {
        let keychain = Keychain(service: appBundle)
        guard let data = keychain[data: file] else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    
    private func secureDelete(_ file: String) {
        let keychain = Keychain(service: appBundle)
        try? keychain.remove(file)
    }
    
    
}
