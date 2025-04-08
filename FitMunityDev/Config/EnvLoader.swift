import Foundation

// Helper class to load environment variables from .env file
class EnvLoader {
    static let shared = EnvLoader()
    
    private init() {
        loadEnv()
    }
    
    func loadEnv() {
        guard let fileURL = Bundle.main.url(forResource: ".env", withExtension: nil) else {
            print("❌ .env file not found in bundle")
            return
        }
        
        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = contents.components(separatedBy: .newlines)
            
            for line in lines {
                // Skip comments and empty lines
                if line.hasPrefix("#") || line.isEmpty {
                    continue
                }
                
                // Parse key=value pairs
                if let range = line.range(of: "=") {
                    let key = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let value = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    
                    if !key.isEmpty && !value.isEmpty {
                        setenv(key, value, 1)
                        print("📦 Loaded environment variable: \(key)")
                    }
                }
            }
        } catch {
            print("❌ Error loading .env file: \(error)")
        }
    }
} 