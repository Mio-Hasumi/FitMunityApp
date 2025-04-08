
import SwiftUI
import Supabase

@main
struct FitMunityDevApp: App {
    let persistenceController = PersistenceController.shared
    
    // Initialize state objects with their initial values
    @StateObject private var postsManager: PostsManager
    @StateObject private var aiManager: AIResponseManager
    @StateObject private var calorieManager: CalorieManager
    @StateObject private var authManager: AuthManager
    @StateObject private var passwordResetManager: PasswordResetManager
    @StateObject private var aiResponseManager: AIResponseManager
    
    init() {
        // Initialize all stored properties first
        let auth = AuthManager()
        let posts = PostsManager()
        let ai = AIResponseManager()
        let passwordReset = PasswordResetManager()
        
        // Initialize all StateObjects
        _authManager = StateObject(wrappedValue: auth)
        _postsManager = StateObject(wrappedValue: posts)
        _aiManager = StateObject(wrappedValue: ai)
        _aiResponseManager = StateObject(wrappedValue: ai)
        _calorieManager = StateObject(wrappedValue: CalorieManager.shared)
        _passwordResetManager = StateObject(wrappedValue: passwordReset)
        
        // After all properties are initialized, perform additional setup
        self.performInitialSetup(posts: posts, ai: ai, auth: auth)
    }
    
    // Separate method for setup after initialization
    private func performInitialSetup(posts: PostsManager, ai: AIResponseManager, auth: AuthManager) {
        // Link the managers with auth
        posts.setAuthManager(auth)
        ai.setAuthManager(auth)
        CalorieManager.shared.setAuthManager(auth)
        
        // Set the auth manager for UserData
        UserData.shared.setAuthManager(auth)
        
        // Set up observers
        setupAuthStateObserver(posts: posts, ai: ai, auth: auth)
        
        // Customize appearance
        customizeAppAppearance()
        
        // Load environment variables from .env file
        _ = EnvLoader.shared
        
        print("🚀 DEBUG: Initializing FitMunityDevApp")
        
        // Print Supabase configuration info
        SupabaseConfig.shared.printDebugInfo()
        
        print("✨ DEBUG: AIResponseManager initialized")
        
        // Initialize any buckets needed
         initializeStorageBuckets()
        
        // Clear any existing calorie data
        CalorieManager.shared.clearEntries()
        
        print("👂 DEBUG: Auth state change observer set up")
    }
    
    // Separate function to set up the auth state observer
    func setupAuthStateObserver(posts: PostsManager, ai: AIResponseManager, auth: AuthManager) {
        // Create a notification observer for auth state changes
        NotificationCenter.default.addObserver(
            forName: .authStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let authState = userInfo["authState"] as? AuthState else {
                return
            }
            
            print("🔔 DEBUG: Observed auth state change: \(authState)")
            
            // Handle the auth state change
            switch authState {
            case .signedIn:
                print("👤 DEBUG: User signed in, triggering data refresh")
                
                // Fetch posts when user signs in
                Task {
                    do {
                        try await posts.fetchPosts()
                        print("✅ DEBUG: Posts refreshed after sign in")
                    } catch {
                        print("❌ DEBUG: Failed to refresh posts after sign in: \(error.localizedDescription)")
                    }
                    
                    // Also fetch calorie entries
                    do {
                        try await CalorieManager.shared.fetchEntriesFromSupabase()
                        print("✅ DEBUG: Calorie entries refreshed after sign in")
                    } catch {
                        print("❌ DEBUG: Failed to refresh calorie entries after sign in: \(error.localizedDescription)")
                    }
                }
                
            case .signedOut:
                print("👋 DEBUG: User signed out, clearing cached data")
                CalorieManager.shared.clearEntries()
                
            case .loading:
                print("⏳ DEBUG: Auth state loading")
            }
        }
    }
    
    // Initialize storage buckets in Supabase
    private func initializeStorageBuckets() {
        Task {
            do {
                // Check if post-images bucket exists, if not create it
                print("🔄 Attempting to create or verify post-images bucket...")
                
                // First check if logged in
                if let session = try? await SupabaseConfig.shared.auth.session {
                    print("✅ User session exists for storage initialization: \(session.user.id)")
                } else {
                    print("⚠️ No user session for storage initialization - will try with anon key")
                }
                
                try await SupabaseConfig.shared.client.storage
                    .createBucket(
                        "post-images", 
                        options: .init(public: true)
                    )
                print("✅ Created or verified post-images bucket")
            } catch {
                // If the bucket already exists, this is fine
                if error.localizedDescription.contains("Duplicate") {
                    print("✅ post-images bucket already exists")
                } else {
                    print("⚠️ Error creating storage bucket: \(error.localizedDescription)")
                    
                    // More detailed error info
                    let nsError = error as NSError
                    print("🔍 Storage error domain: \(nsError.domain), code: \(nsError.code)")
                    print("🔍 Full storage error details: \(error)")
                    
                    if let errorUserInfo = nsError.userInfo as? [String: Any] {
                        print("🔍 Storage error user info: \(errorUserInfo)")
                    }
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AuthView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(postsManager)
                    .environmentObject(aiManager)
                    .environmentObject(calorieManager)
                    .environmentObject(authManager)
                    .environmentObject(passwordResetManager)
                
                // Show new password view when reset token is available
                if passwordResetManager.showNewPasswordView, 
                   let token = passwordResetManager.resetToken {
                    NewPasswordView(resetToken: token)
                        .environmentObject(authManager)
                        .environmentObject(passwordResetManager)
                }
            }
            .onOpenURL { url in
                // Handle deep links
                handleDeepLink(url)
            }
            // Force light mode to ensure consistent appearance
            .preferredColorScheme(.light)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("DEBUG: Received URL: \(url)")
        
        // Parse the URL components
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            print("DEBUG: Failed to parse URL components")
            return
        }
        
        print("DEBUG: Query Items:")
        for item in queryItems {
            print("  - \(item.name): \(item.value ?? "nil")")
        }
        
        // Check for type parameter to distinguish between confirmation and reset
        let type = queryItems.first(where: { $0.name == "type" })?.value
        print("DEBUG: Link type: \(type ?? "nil")")
        
        // Check for OAuth code
        if let code = queryItems.first(where: { $0.name == "code" })?.value {
            print("DEBUG: Found OAuth code: \(code)")
            
            // Determine the grant type based on the link type or path
            let grantType: String
            if type == "recovery" || url.absoluteString.contains("reset") {
                grantType = "recovery" // Password reset
                print("DEBUG: Processing as password reset link")
            } else if type == "signup" || url.absoluteString.contains("confirm") {
                grantType = "signup" // Email confirmation
                print("DEBUG: Processing as email confirmation link")
            } else {
                // Default to email confirmation if unclear
                grantType = "signup"
                print("DEBUG: No type specified, defaulting to email confirmation")
            }
            
            // Exchange the code for a session
            Task {
                do {
                    // Get a reference to the Supabase auth client directly
                    let auth = SupabaseConfig.shared.auth
                    
                    // Create the complete URL for session exchange
                    let baseUrl = SupabaseConfig.shared.supabaseUrl
                    var components = URLComponents(string: baseUrl)!
                    components.path = "/auth/v1/token"
                    components.queryItems = [
                        URLQueryItem(name: "code", value: code),
                        URLQueryItem(name: "grant_type", value: grantType)
                    ]
                    
                    guard let sessionUrl = components.url else {
                        print("DEBUG: Failed to create session URL")
                        return
                    }
                    
                    let session = try await auth.session(from: sessionUrl)
                    print("DEBUG: Successfully exchanged code for session")
                    
                    await MainActor.run {
                        if grantType == "recovery" {
                            // Show password reset view for recovery links
                            passwordResetManager.showPasswordResetView(withToken: session.accessToken)
                        } else {
                            // For email confirmation, just update the auth state
                            // The auth state change will be detected and handled automatically
                            print("DEBUG: Email confirmed successfully")
                            // You may want to show a confirmation message to the user
                        }
                    }
                } catch {
                    print("DEBUG: Failed to exchange code for session: \(error)")
                }
            }
        }
    }

    // Function to customize app appearance
    private func customizeAppAppearance() {
        // Set up navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = .white
        navigationBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.primaryColor)
        ]
        navigationBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppTheme.primaryColor)
        ]
        
        // Apply navigation bar appearance settings
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        
        // Set up tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .white
        
        // Apply tab bar appearance settings
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Set up table view appearance
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        
        // Set up text field appearance
        UITextField.appearance().tintColor = UIColor(AppTheme.primaryColor)
    }
}
