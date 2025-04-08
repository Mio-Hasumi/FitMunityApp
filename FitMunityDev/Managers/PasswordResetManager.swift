import SwiftUI

class PasswordResetManager: ObservableObject {
    @Published var resetToken: String?
    @Published var showNewPasswordView = false
    
    static let shared = PasswordResetManager()
    
    func dismissPasswordResetView() {
        resetToken = nil
        showNewPasswordView = false
    }
    
    func showPasswordResetView(withToken token: String) {
        resetToken = token
        showNewPasswordView = true
    }
} 