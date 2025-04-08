import SwiftUI

struct RegistrationView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingPasswordRequirements = false
    @State private var showConfirmationMessage = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(hex: "FFF8DD")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Logo and branding
                        VStack(spacing: 10) {
                            Image(systemName: "figure.run.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.black)
                            
                            Text("Sign Up")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Create your FitMunity account")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.bottom, 20)
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
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .onChange(of: password) { _ in
                                    // Show password requirements when user starts typing
                                    if !password.isEmpty {
                                        showingPasswordRequirements = true
                                    }
                                }
                            
                            if showingPasswordRequirements {
                                PasswordRequirementsView(password: password)
                                    .padding(.vertical, 5)
                            }
                            
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
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
                            
                            // Sign up button
                            Button(action: signUp) {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(height: 50)
                                        .cornerRadius(10)
                                    
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Create Account")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    }
                                }
                            }
                            .disabled(isLoading)
                            .padding(.top, 20)
                            
                            if showConfirmationMessage {
                                Text("Please check your email to confirm your account.")
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 10)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Terms and conditions text
                        Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
    
    private func signUp() {
        // Reset error message and confirmation message
        errorMessage = ""
        showConfirmationMessage = false
        
        // Validate input
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "All fields are required"
            return
        }
        
        guard authManager.isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        guard authManager.isValidPassword(password) else {
            errorMessage = "Password doesn't meet the requirements"
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        
        // Start loading
        isLoading = true
        errorMessage = "Creating your account..."
        
        // Attempt to sign up
        Task {
            do {
                print("🔄 Starting registration for: \(email)")
                let success = try await authManager.signUp(email: email, password: password)
                
                await MainActor.run {
                    isLoading = false
                    if success {
                        errorMessage = ""
                        showConfirmationMessage = true
                        // Dismiss the registration view after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else {
                        errorMessage = "Failed to create account. Please try again."
                    }
                }
            } catch let error as AuthError {
                await MainActor.run {
                    isLoading = false
                    
                    // Show appropriate error message based on the error type
                    switch error {
                    case .userAlreadyExists:
                        errorMessage = "This email is already registered. Please sign in instead."
                    case .invalidEmail:
                        errorMessage = "Please enter a valid email address."
                    case .invalidPassword:
                        errorMessage = "Your password doesn't meet the security requirements."
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
                    print("Registration error: \(error)")
                }
            }
        }
    }
}

// Password requirements helper view
struct PasswordRequirementsView: View {
    let password: String
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Password must:")
                .font(.caption)
                .foregroundColor(.gray)
            
            Group {
                requirementText("Be at least \(authManager.passwordMinLength) characters", 
                               met: password.count >= authManager.passwordMinLength)
                
                if authManager.passwordRequiresUppercase {
                    requirementText("Contain at least one uppercase letter", 
                                  met: password.range(of: "[A-Z]", options: .regularExpression) != nil)
                }
                
                if authManager.passwordRequiresLowercase {
                    requirementText("Contain at least one lowercase letter", 
                                  met: password.range(of: "[a-z]", options: .regularExpression) != nil)
                }
                
                if authManager.passwordRequiresNumber {
                    requirementText("Contain at least one number", 
                                  met: password.range(of: "[0-9]", options: .regularExpression) != nil)
                }
                
                if authManager.passwordRequiresSpecialChar {
                    requirementText("Contain at least one special character", 
                                  met: password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil)
                }
            }
        }
        .padding(.horizontal, 5)
    }
    
    private func requirementText(_ text: String, met: Bool) -> some View {
        HStack {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundColor(met ? .green : .gray)
                .font(.system(size: 12))
            
            Text(text)
                .font(.caption)
                .foregroundColor(met ? .green : .gray)
        }
    }
}

struct PasswordRequirementsView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordRequirementsView(password: "Example123!")
            .environmentObject(AuthManager())
    }
}

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        RegistrationView()
            .environmentObject(AuthManager())
    }
} 