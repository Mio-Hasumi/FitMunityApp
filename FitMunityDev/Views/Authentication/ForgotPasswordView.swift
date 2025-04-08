import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
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
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 60))
                                .foregroundColor(.black)
                            
                            Text("Reset Password")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Enter your email to receive a password reset link")
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
                            
                            // Error message
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                                    .padding(.top, 5)
                            }
                            
                            // Success message
                            if !successMessage.isEmpty {
                                Text(successMessage)
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                                    .padding(.top, 5)
                            }
                            
                            // Reset password button
                            Button(action: resetPassword) {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(height: 50)
                                        .cornerRadius(10)
                                    
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Send Reset Link")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    }
                                }
                            }
                            .disabled(isLoading)
                            .padding(.top, 20)
                        }
                        .padding(.horizontal, 30)
                        
                        // Back to login
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Back to Login")
                                .foregroundColor(.black)
                                .font(.subheadline)
                                .underline()
                        }
                        .padding(.top, 20)
                    }
                    .padding(.vertical, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func resetPassword() {
        // Reset messages
        errorMessage = ""
        successMessage = ""
        
        // Validate input
        guard !email.isEmpty else {
            errorMessage = "Email is required"
            return
        }
        
        guard authManager.isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        // Start loading
        isLoading = true
        
        // Attempt to send reset password email
        Task {
            do {
                let success = try await authManager.resetPassword(email: email)
                
                await MainActor.run {
                    isLoading = false
                    if success {
                        successMessage = "Password reset link sent to your email. Please check your inbox."
                        // Clear the email field
                        email = ""
                    } else {
                        errorMessage = "Failed to send reset link. Please try again."
                    }
                }
            } catch let error as AuthError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "An unexpected error occurred. Please try again."
                }
            }
        }
    }
}

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordView()
            .environmentObject(AuthManager())
    }
} 