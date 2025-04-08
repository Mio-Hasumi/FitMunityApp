import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showRegistration = false
    @State private var showingForgotPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(hex: "FFF8DD")
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Logo and branding
                    VStack(spacing: 10) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.black)
                        
                        Text("FitMunity")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Your social fitness community")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 40)
                    }
                    
                    // Form fields
                    VStack(spacing: 15) {
                        TextField("Email", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        // Error message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                        
                        // Sign in button
                        Button(action: signIn) {
                            ZStack {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(height: 50)
                                    .cornerRadius(10)
                                
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign In")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                }
                            }
                        }
                        .disabled(isLoading)
                        .padding(.top, 20)
                        
                        // Forgot password link
                        Button(action: {
                            showingForgotPassword = true
                        }) {
                            Text("Forgot Password?")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                                .underline()
                        }
                        .padding(.top, 10)
                        
                        // Sign up button
                        Button(action: {
                            showRegistration = true
                        }) {
                            Text("Don't have an account? Sign Up")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 30)
                    
                    // Terms and conditions text
                    Text("By signing in, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    
                    Spacer()
                }
                .padding(.top, 60)
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showRegistration) {
                RegistrationView()
                    .environmentObject(authManager)
            }
            .fullScreenCover(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
                    .environmentObject(authManager)
            }
        }
    }
    
    private func signIn() {
        // Reset error message
        errorMessage = ""
        
        // Validate input
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            return
        }
        
        // Start loading
        isLoading = true
        
        // Attempt to sign in
        Task {
            do {
                print("🔄 Attempting login for: \(email)")
                let success = try await authManager.signIn(email: email, password: password)
                
                await MainActor.run {
                    isLoading = false
                    if !success {
                        errorMessage = "Login failed. Please try again."
                    }
                }
            } catch let error as AuthError {
                await MainActor.run {
                    isLoading = false
                    
                    // Show appropriate error message based on the error type
                    switch error {
                    case .invalidCredentials:
                        errorMessage = "Invalid email or password. Please try again."
                    case .emailNotConfirmed:
                        errorMessage = "Please confirm your email before signing in."
                    case .networkError:
                        errorMessage = "Cannot connect to the server. Please check your internet connection."
                    default:
                        errorMessage = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "An error occurred: \(error.localizedDescription)"
                    print("Login error: \(error)")
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthManager())
    }
} 