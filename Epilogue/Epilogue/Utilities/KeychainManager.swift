import Foundation
import Security

/// Secure storage for sensitive data like API keys
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case itemNotFound
        case invalidData
    }
    
    // MARK: - Save to Keychain
    
    func save(key: String, value: String, service: String = "com.epilogue.app") throws {
        // Convert string to data
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // Create query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }
    
    // MARK: - Retrieve from Keychain
    
    func retrieve(key: String, service: String = "com.epilogue.app") throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unknown(status)
        }
        
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return string
    }
    
    // MARK: - Delete from Keychain
    
    func delete(key: String, service: String = "com.epilogue.app") throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    // MARK: - Check if exists
    
    func exists(key: String, service: String = "com.epilogue.app") -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - API Key Storage Extension

extension KeychainManager {
    private static let perplexityAPIKeyIdentifier = "perplexity_api_key"
    
    func savePerplexityAPIKey(_ apiKey: String) throws {
        try save(key: Self.perplexityAPIKeyIdentifier, value: apiKey)
    }
    
    func getPerplexityAPIKey() -> String? {
        try? retrieve(key: Self.perplexityAPIKeyIdentifier)
    }
    
    func deletePerplexityAPIKey() throws {
        try delete(key: Self.perplexityAPIKeyIdentifier)
    }
    
    var hasPerplexityAPIKey: Bool {
        exists(key: Self.perplexityAPIKeyIdentifier)
    }
    
    // MARK: - Security Validation
    
    /// Validates API key format (basic check)
    func isValidAPIKey(_ apiKey: String) -> Bool {
        // Basic validation - not empty and reasonable length
        guard !apiKey.isEmpty,
              apiKey.count >= 20,
              apiKey.count <= 200 else {
            return false
        }
        
        // Check for common placeholder patterns
        let placeholders = ["your-api-key", "placeholder", "xxxxxxxx", "api_key_here"]
        for placeholder in placeholders {
            if apiKey.lowercased().contains(placeholder) {
                return false
            }
        }
        
        // Only allow alphanumeric, dash, and underscore
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return apiKey.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
    
    /// Migrate API key from Info.plist to Keychain
    func migrateAPIKeyFromBundle() {
        // Check if already migrated
        if hasPerplexityAPIKey { return }
        
        // Try to get from bundle
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "PERPLEXITY_API_KEY") as? String,
           isValidAPIKey(apiKey) {
            do {
                try savePerplexityAPIKey(apiKey)
                print("✅ Migrated API key to secure storage")
            } catch {
                print("❌ Failed to migrate API key: \(error)")
            }
        }
    }
}