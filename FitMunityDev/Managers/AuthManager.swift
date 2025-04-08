import Foundation
import SwiftUI
import Supabase
import Combine

// Auth manager that uses Supabase for authentication
class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var authState: AuthState = .loading {
        didSet {
            if oldValue != authState {
                // Broadcast notification when auth state changes
                NotificationCenter.default.post(name: .authStateChanged, object: nil, userInfo: ["authState": authState])
            }
        }
    }
    
    // For password validation
    let passwordMinLength = 8
    let passwordRequiresUppercase = true
    let passwordRequiresLowercase = true
    let passwordRequiresNumber = true
    let passwordRequiresSpecialChar = true
    
    // User session storage key
    private let userSessionKey = "fitMunityUserSession"
    
    // Subscribers
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Check for existing session on launch
        Task {
            await checkAuth()
        }
        
        // Listen for auth state changes from Supabase
        setupAuthStateListener()
    }
    
    // Setup auth state listener
    private func setupAuthStateListener() {
        // This would ideally subscribe to Supabase auth state changes.
        // For now, we'll implement a simple polling mechanism to check auth state.
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.checkAuth()
                }
            }
            .store(in: &cancellables)
    }
    
    // Check if user is authenticated with Supabase
    private func checkAuth() async {
        do {
            // Get the current session
            let session = try await SupabaseConfig.shared.auth.session
            
            // Since we have a valid session, user is authenticated
            let user = session.user
            
            // print("✅ User authenticated: \(user.email ?? "no email")")
            
            // Extract username from metadata, fallback to email
            let username = extractUsername(from: user)
            
            await MainActor.run {
                self.currentUser = User(
                    id: user.id.uuidString,
                    email: user.email ?? "",
                    username: username,
                    createdAt: Date()
                )
                self.authState = .signedIn
            }
        } catch {
            print("👤 User not authenticated: \(error.localizedDescription)")
            await MainActor.run {
                self.currentUser = nil
                self.authState = .signedOut
            }
        }
    }
    
    // Extract username from user metadata with fallbacks
    private func extractUsername(from user: Supabase.User) -> String {
        // Try to get username from metadata
        if let username = user.userMetadata["username"] as? String {
            return username
        }
        
        // Fallback to email prefix
        if let email = user.email, email.contains("@") {
            return email.components(separatedBy: "@")[0]
        }
        
        // Last resort fallback
        return "user_\(user.id.uuidString.prefix(6))"
    }
    
    // Sign up with Supabase
    func signUp(email: String, password: String) async throws -> Bool {
        print("🔐 Signing up user with email: \(email)")
        
        do {
            print("📊 Checking Supabase connection...")
            let client = SupabaseConfig.shared
            print("📊 Supabase URL: \(client.supabaseUrl)")
            
            // Test database connection first
            do {
                print("🔄 Testing database connection...")
                let testResponse = try await client.database.from("profiles").select().limit(1).execute()
                print("✅ Database connection test successful: \(testResponse.status)")
            } catch {
                print("❌ Database connection test failed: \(error.localizedDescription)")
                if let dbError = error as? PostgrestError {
                    print("🔍 PostgrestError details: \(dbError)")
                    print("🔍 Error message: \(dbError.localizedDescription)")
                }
            }
            
            // Try signup with full debug
            print("🔄 Attempting signup with Supabase auth...")
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )
            
            print("✅ User created with ID: \(response.user.id)")
            print("✅ Session: \(response.session != nil ? "Created" : "Not created")")
            
            // Return success
            return true
        } catch {
            let nsError = error as NSError
            print("❌ Sign up error: \(error.localizedDescription)")
            print("❌ Error domain: \(nsError.domain), code: \(nsError.code)")
            
            // More detailed error info
            print("🔍 Full error details: \(error)")
            if let errorUserInfo = nsError.userInfo as? [String: Any] {
                print("🔍 Error user info: \(errorUserInfo)")
            }
            
            // Check for Supabase-specific error types
            if let supabaseError = error as? AuthError {
                print("🔍 Supabase AuthError type: \(supabaseError)")
            }
            
            if let authError = error as? GoTrueError {
                print("🔍 GoTrueError details: \(authError)")
                print("🔍 Error message: \(authError.localizedDescription)")
            }
            
            // Map common errors
            if nsError.localizedDescription.contains("already registered") {
                throw AuthError.userAlreadyExists
            } else if nsError.domain.contains("URLError") {
                throw AuthError.networkError
            } else {
                throw AuthError.authError(message: nsError.localizedDescription)
            }
        }
    }
    
    // Sign in with Supabase
    func signIn(email: String, password: String) async throws -> Bool {
        print("🔐 Signing in user with email: \(email)")
        
        do {
            // Attempt sign in
            let response = try await SupabaseConfig.shared.auth.signIn(
                email: email,
                password: password
            )
            
            print("✅ Sign in successful for user: \(response.user.id)")
            
            // Extract username from metadata, fallback to email
            let username = extractUsername(from: response.user)
            
            // Update user state
            await MainActor.run {
                self.currentUser = User(
                    id: response.user.id.uuidString,
                    email: response.user.email ?? "",
                    username: username,
                    createdAt: Date()
                )
                self.authState = .signedIn
            }
            
            return true
        } catch {
            let nsError = error as NSError
            print("❌ Sign in error: \(error.localizedDescription)")
            print("❌ Error domain: \(nsError.domain), code: \(nsError.code)")
            
            // Map common errors
            if nsError.localizedDescription.contains("Invalid login") {
                throw AuthError.invalidCredentials
            } else if nsError.localizedDescription.contains("Email not confirmed") {
                throw AuthError.emailNotConfirmed
            } else if nsError.domain.contains("URLError") {
                throw AuthError.networkError
            } else {
                throw AuthError.authError(message: nsError.localizedDescription)
            }
        }
    }
    
    // Sign out the current user
    func signOut() {
        Task {
            do {
                try await SupabaseConfig.shared.auth.signOut()
                print("✅ User signed out successfully")
                
                await MainActor.run {
                    self.currentUser = nil
                    self.authState = .signedOut
                }
            } catch {
                print("❌ Sign out error: \(error.localizedDescription)")
                
                // Clean up local state regardless of error
                await MainActor.run {
                    self.currentUser = nil
                    self.authState = .signedOut
                }
            }
        }
    }
    
    // Validate email format
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // Validate username
    func isValidUsername(_ username: String) -> Bool {
        // Username should be at least 3 characters, alphanumeric with underscores allowed
        let usernameRegex = "^[a-zA-Z0-9_]{3,}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    // Validate password strength
    func isValidPassword(_ password: String) -> Bool {
        // Check minimum length
        guard password.count >= passwordMinLength else { return false }
        
        // Check for uppercase letters if required
        if passwordRequiresUppercase {
            guard password.range(of: "[A-Z]", options: .regularExpression) != nil else { return false }
        }
        
        // Check for lowercase letters if required
        if passwordRequiresLowercase {
            guard password.range(of: "[a-z]", options: .regularExpression) != nil else { return false }
        }
        
        // Check for numbers if required
        if passwordRequiresNumber {
            guard password.range(of: "[0-9]", options: .regularExpression) != nil else { return false }
        }
        
        // Check for special characters if required
        if passwordRequiresSpecialChar {
            guard password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil else { return false }
        }
        
        return true
    }
    
    // Reset password (send password reset email)
    func resetPassword(email: String) async throws -> Bool {
        print("🔐 Sending password reset email to: \(email)")
        
        do {
            try await SupabaseConfig.shared.auth.resetPasswordForEmail(email)
            print("✅ Password reset email sent successfully")
            return true
        } catch {
            let nsError = error as NSError
            print("❌ Password reset error: \(error.localizedDescription)")
            
            // Map common errors
            if nsError.localizedDescription.contains("Email not found") {
                throw AuthError.invalidEmail
            } else if nsError.domain.contains("URLError") {
                throw AuthError.networkError
            } else {
                throw AuthError.authError(message: nsError.localizedDescription)
            }
        }
    }
    
    // Update password with reset token
    func updatePassword(token: String, newPassword: String) async throws -> Bool {
        print("🔐 Updating password with token")
        
        do {
            try await SupabaseConfig.shared.auth.setSession(accessToken: token, refreshToken: "")
            try await SupabaseConfig.shared.auth.update(user: UserAttributes(password: newPassword))
            try await SupabaseConfig.shared.auth.signOut()
            
            print("✅ Password updated successfully")
            
            await MainActor.run {
                self.currentUser = nil
                self.authState = .signedOut
            }
            
            return true
        } catch {
            print("❌ Password update error: \(error.localizedDescription)")
            throw AuthError.authError(message: error.localizedDescription)
        }
    }
}

// Authentication errors
enum AuthError: Error, LocalizedError {
    case invalidEmail
    case invalidPassword
    case invalidUsername
    case invalidCredentials
    case userAlreadyExists
    case networkError
    case unknown
    case emailNotConfirmed
    case supabaseNotConfigured
    case authError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .invalidPassword:
            return "Password doesn't meet the requirements."
        case .invalidUsername:
            return "Username must be at least 3 characters and contain only letters, numbers, and underscores."
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .userAlreadyExists:
            return "A user with this email already exists."
        case .networkError:
            return "Unable to connect to the authentication service. Please check your internet connection and try again."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        case .emailNotConfirmed:
            return "Please confirm your email address before signing in. Check your inbox for the confirmation link."
        case .supabaseNotConfigured:
            return "Supabase is not properly configured."
        case .authError(let message):
            return message
        }
    }
}

// First, add an extension for Notification.Name
extension Notification.Name {
    static let authStateChanged = Notification.Name("AuthStateChanged")
}
