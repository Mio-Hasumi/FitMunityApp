import Foundation

enum Config {
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("Info.plist file not found")
        }
        return dict
    }()
    
    static let openAIApiKey: String = {
        print("⚙️ Config: Starting API key resolution")
        
        // Try to read from .env file
        let envFilePaths = [
            // Project root
            FileManager.default.currentDirectoryPath + "/.env",
            // One level up (common for Xcode projects)
            (FileManager.default.currentDirectoryPath as NSString).deletingLastPathComponent + "/.env",
            // Two levels up
            ((FileManager.default.currentDirectoryPath as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent + "/.env",
            // Try absolute path
            "/Users/yufanchen/Desktop/FitMunityDev-main/.env"
        ]
        
        print("⚙️ Config: Current directory: \(FileManager.default.currentDirectoryPath)")
        
        for path in envFilePaths {
            print("⚙️ Config: Checking path: \(path)")
            
            if FileManager.default.fileExists(atPath: path) {
                print("⚙️ Config: .env file found at: \(path)")
                
                do {
                    let envContents = try String(contentsOfFile: path, encoding: .utf8)
                    print("⚙️ Config: Read .env file, length: \(envContents.count) characters")
                    
                    let lines = envContents.components(separatedBy: .newlines)
                    print("⚙️ Config: Lines in .env: \(lines.count)")
                    
                    for line in lines {
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if trimmedLine.hasPrefix("OPENAI_API_KEY=") {
                            print("⚙️ Config: Found OPENAI_API_KEY in .env")
                            
                            let keyValue = trimmedLine.dropFirst("OPENAI_API_KEY=".count)
                            if !keyValue.isEmpty {
                                let apiKey = String(keyValue)
                                print("⚙️ Config: Using API key from .env: \(apiKey.prefix(8))...")
                                return apiKey
                            }
                        }
                    }
                } catch {
                    print("⚙️ Config: Error reading .env file: \(error)")
                }
            }
        }
        
        // Fallback to hardcoded key
        print("⚙️ Config: Using hardcoded API key")
        return "placeholderx"
    }()
} 
