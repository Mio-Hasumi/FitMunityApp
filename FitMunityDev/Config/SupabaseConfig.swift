import Foundation
import Supabase

class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    // Supabase client
    let client: SupabaseClient
    
    // Supabase URL and key from the .env file
    let supabaseUrl = "https://lcygoiajlquzhawfzhma.supabase.co"
    let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxjeWdvaWFqbHF1emhhd2Z6aG1hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM1Nzk5OTMsImV4cCI6MjA1OTE1NTk5M30.MGkGuZXMSXy4_oX2XyuyOumdqS8v4dZeiiLf0fhqAHA"
    
    private init() {
        print("📊 Initializing Supabase client...")
        print("📊 URL: \(supabaseUrl)")
        
        // Initialize the client without try/catch as the initializer isn't throwing
        client = SupabaseClient(
            supabaseURL: URL(string: supabaseUrl)!,
            supabaseKey: supabaseKey
        )
        
        print("✅ Supabase client initialized successfully")
    }
    
    // Convenience accessor for auth client
    var auth: GoTrueClient {
        return client.auth
    }
    
    // Convenience accessor for database
    var database: PostgrestClient {
        return client.database
    }
    
    // Debug information
    func printDebugInfo() {
        print("=== SUPABASE CONFIGURATION DEBUG INFO ===")
        print("URL: \(supabaseUrl)")
        print("Key: \(String(supabaseKey.prefix(15)))...")
        print("=========================================")
    }
} 