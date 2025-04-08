import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var userData = UserData.shared
    @State private var showOnboarding = false
    @State private var forceRefresh: Bool = false
    
    var body: some View {
        ZStack {
            switch authManager.authState {
            case .signedIn:
                if !userData.hasCompletedOnboarding {
                    OnboardingView {
                        // When onboarding is finished
                        userData.saveUserData() // This will also set hasCompletedOnboarding to true
                        showOnboarding = false
                    }
                    .transition(.opacity)
                } else {
                    MainAppView()
                        .transition(.opacity)
                }
            case .signedOut:
                LoginView()
                    .transition(.opacity)
            case .loading:
                LoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: authManager.authState)
        .animation(.easeInOut, value: forceRefresh)
        .onAppear {
            // Listen for force sign out notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ForceSignOut"),
                object: nil,
                queue: .main
            ) { _ in
                // Force a refresh by toggling this state
                forceRefresh.toggle()
                // Ensure auth state is correct
                authManager.authState = .signedOut
            }
        }
    }
    
    // Loading view while checking authentication state
    private var loadingView: some View {
        ZStack {
            Color(hex: "FFF8DD")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.black)
                
                Text("FitMunity")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.black)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding(.top, 20)
            }
        }
    }
}

// Loading View
struct LoadingView: View {
    var body: some View {
        ZStack {
            AppTheme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .tint(AppTheme.primaryColor)
                
                Text("Loading...")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.primaryColor)
            }
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthManager()
        
        Group {
            AuthView()
                .environmentObject(authManager)
                .previewDisplayName("Loading")
            
            AuthView()
                .environmentObject({ 
                    let manager = AuthManager()
                    manager.authState = .signedOut
                    return manager
                }())
                .previewDisplayName("Signed Out")
            
            AuthView()
                .environmentObject({ 
                    let manager = AuthManager()
                    manager.authState = .signedIn
                    manager.currentUser = User(id: "preview", email: "test@example.com", username: "test_user", createdAt: Date())
                    return manager
                }())
                .previewDisplayName("Signed In")
        }
    }
} 