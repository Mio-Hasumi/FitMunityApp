import SwiftUI

struct NewPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var passwordResetManager: PasswordResetManager
    
    let resetToken: String
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingPasswordRequirements = false
    @State private var showSuccessMessage = false
    
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
                            
                            Text("Set New Password")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Enter your new password")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.bottom, 20)
                        }
                        
                        // Form fields
                        VStack(spacing: 15) {
                            SecureField("New Password", text: $newPassword)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .onChange(of: newPassword) { _ in
                                    showingPasswordRequirements = !newPassword.isEmpty
                                }
                            
                            if showingPasswordRequirements {
                                PasswordRequirementsView(password: newPassword)
                                    .padding(.vertical, 5)
                            }
                            
                            SecureField("Confirm New Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.horizontal)
                            }
                            
                            // Reset password button
                            Button(action: updatePassword) {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(height: 50)
                                        .cornerRadius(10)
                                    
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Update Password")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    }
                                }
                            }
                            .disabled(isLoading)
                            .padding(.top, 20)
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.vertical, 30)
                }
                
                // Success message overlay
                if showSuccessMessage {
                    VStack {
                        Spacer()
                        Text("Password updated successfully!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                            .shadow(radius: 3)
                        Spacer()
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func updatePassword() {
        // Reset error message
        errorMessage = ""
        
        // Validate passwords
        guard !newPassword.isEmpty else {
            errorMessage = "Please enter a new password"
            return
        }
        
        guard authManager.isValidPassword(newPassword) else {
            errorMessage = "Password doesn't meet the requirements"
            return
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        
        // Start loading
        isLoading = true
        
        // Update password
        Task {
            do {
                let success = try await authManager.updatePassword(token: resetToken, newPassword: newPassword)
                
                await MainActor.run {
                    isLoading = false
                    if success {
                        // Show success message briefly
                        showSuccessMessage = true
                        
                        // Dismiss after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            // Dismiss the NewPasswordView
                            passwordResetManager.dismissPasswordResetView()
                        }
                    } else {
                        errorMessage = "Failed to update password. Please try again."
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

struct NewPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        NewPasswordView(resetToken: "preview-token")
            .environmentObject(AuthManager())
    }
} 