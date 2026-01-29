//
//  AuthView.swift
//  lambdas-xi-chapter
//
//  Clerk-based authentication UI. Supports:
//  - Email + username + password registration with OTP verification
//  - Email/username + password sign in
//  - Sign in with Apple
//  - Password reset
//  Debug: Uses AuthService for all Clerk operations
//

import SwiftUI
// TODO: Uncomment when Apple Developer Account is available
// import AuthenticationServices

// MARK: - Auth Mode

/// Current authentication flow mode
/// Debug: Tracks which form/screen to display
enum AuthMode {
    case signIn
    case register
    case verifyEmail
    case forgotPassword
    case resetPassword
}

// MARK: - Auth View

/// Main authentication view with multiple flows
/// Debug: Observes AuthService for state changes
struct AuthView: View {
    @StateObject private var auth = AuthService.shared
    
    // Form state
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var verificationCode = ""
    @State private var newPassword = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerView
                
                // Main form based on mode
                switch mode {
                case .signIn:
                    signInForm
                case .register:
                    registerForm
                case .verifyEmail:
                    verifyEmailForm
                case .forgotPassword:
                    forgotPasswordForm
                case .resetPassword:
                    resetPasswordForm
                }
                
                // Error message
                if let error = auth.errorMessage {
                    errorMessageView(error)
                }
                
                // Loading indicator
                if auth.authState == .authenticating {
                    loadingView
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onChange(of: auth.authState) { _, newState in
            // Debug: Handle auth state changes
            handleAuthStateChange(newState)
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: headerIcon)
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text(headerTitle)
                .font(.title.bold())
            
            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var headerIcon: String {
        switch mode {
        case .signIn: return "person.circle.fill"
        case .register: return "person.badge.plus"
        case .verifyEmail: return "envelope.badge.fill"
        case .forgotPassword, .resetPassword: return "key.fill"
        }
    }
    
    private var headerTitle: String {
        switch mode {
        case .signIn: return "Welcome Back"
        case .register: return "Create Account"
        case .verifyEmail: return "Verify Email"
        case .forgotPassword: return "Reset Password"
        case .resetPassword: return "Set New Password"
        }
    }
    
    private var headerSubtitle: String {
        switch mode {
        case .signIn: return "Sign in to continue"
        case .register: return "Join Lambdas Xi Chapter"
        case .verifyEmail: return "Enter the code sent to your email"
        case .forgotPassword: return "We'll send you a reset code"
        case .resetPassword: return "Enter the code and your new password"
        }
    }
    
    // MARK: - Sign In Form
    
    private var signInForm: some View {
        VStack(spacing: 16) {
            // Email/Username field
            VStack(alignment: .leading, spacing: 4) {
                Text("Email or Username")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Enter email or username", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .disabled(auth.authState == .authenticating)
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                SecureField("Enter password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .disabled(auth.authState == .authenticating)
            }
            
            // Sign In button
            primaryButton(title: "Sign In") {
                Task {
                    await auth.login(identifier: email, password: password)
                }
            }
            .disabled(email.isEmpty || password.isEmpty || auth.authState == .authenticating)
            
            // Forgot password link
            Button {
                withAnimation { mode = .forgotPassword }
                clearFields()
            } label: {
                Text("Forgot password?")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            
            // Divider
            // TODO: Uncomment when Apple Developer Account is available
            // dividerWithText("or")
            
            // Sign in with Apple (Requires Apple Developer Account)
            // signInWithAppleButton
            
            // Switch to register
            switchModeButton(
                text: "Don't have an account?",
                action: "Create Account"
            ) {
                withAnimation { mode = .register }
                clearFields()
            }
        }
    }
    
    // MARK: - Register Form
    
    private var registerForm: some View {
        VStack(spacing: 16) {
            // Email field
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Enter email address", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .disabled(auth.authState == .authenticating)
            }
            
            // Username field
            VStack(alignment: .leading, spacing: 4) {
                Text("Username")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Choose a username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(auth.authState == .authenticating)
                
                Text("3-20 characters, letters, numbers, underscores only")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                SecureField("Enter password (8+ characters)", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .disabled(auth.authState == .authenticating)
            }
            
            // Confirm password field
            VStack(alignment: .leading, spacing: 4) {
                Text("Confirm Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                SecureField("Re-enter password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .disabled(auth.authState == .authenticating)
            }
            
            // Create Account button
            primaryButton(title: "Create Account") {
                Task {
                    await auth.register(
                        email: email,
                        username: username,
                        password: password,
                        confirmPassword: confirmPassword
                    )
                }
            }
            .disabled(
                email.isEmpty || username.isEmpty || password.isEmpty || 
                confirmPassword.isEmpty || auth.authState == .authenticating
            )
            
            // Divider
            // TODO: Uncomment when Apple Developer Account is available
            // dividerWithText("or")
            
            // Sign in with Apple (Requires Apple Developer Account)
            // signInWithAppleButton
            
            // Switch to sign in
            switchModeButton(
                text: "Already have an account?",
                action: "Sign In"
            ) {
                withAnimation { mode = .signIn }
                clearFields()
            }
        }
    }
    
    // MARK: - Verify Email Form
    
    private var verifyEmailForm: some View {
        VStack(spacing: 16) {
            // Show which email the code was sent to
            if case .needsVerification(let sentEmail) = auth.authState {
                Text("Code sent to \(sentEmail)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Verification code field
            VStack(alignment: .leading, spacing: 4) {
                Text("Verification Code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Enter 6-digit code", text: $verificationCode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .disabled(auth.authState == .authenticating)
            }
            
            // Verify button
            primaryButton(title: "Verify") {
                Task {
                    await auth.verifyEmail(code: verificationCode)
                }
            }
            .disabled(verificationCode.isEmpty || auth.authState == .authenticating)
            
            // Resend code button
            Button {
                Task {
                    await auth.resendVerificationCode()
                }
            } label: {
                Text("Resend code")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            .disabled(auth.authState == .authenticating)
            
            // Cancel button
            Button {
                auth.cancelAuthFlow()
                withAnimation { mode = .register }
                clearFields()
            } label: {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Forgot Password Form
    
    private var forgotPasswordForm: some View {
        VStack(spacing: 16) {
            // Email field
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Enter your email address", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .disabled(auth.authState == .authenticating)
            }
            
            // Send Reset Code button
            primaryButton(title: "Send Reset Code") {
                Task {
                    await auth.resetPassword(email: email)
                }
            }
            .disabled(email.isEmpty || auth.authState == .authenticating)
            
            // Back to sign in
            Button {
                withAnimation { mode = .signIn }
                clearFields()
            } label: {
                Text("Back to Sign In")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        }
    }
    
    // MARK: - Reset Password Form
    
    private var resetPasswordForm: some View {
        VStack(spacing: 16) {
            // Show which email the code was sent to
            if case .needsVerification(let sentEmail) = auth.authState {
                Text("Code sent to \(sentEmail)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Verification code field
            VStack(alignment: .leading, spacing: 4) {
                Text("Reset Code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Enter code from email", text: $verificationCode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .disabled(auth.authState == .authenticating)
            }
            
            // New password field
            VStack(alignment: .leading, spacing: 4) {
                Text("New Password")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                SecureField("Enter new password (8+ characters)", text: $newPassword)
                    .textFieldStyle(.roundedBorder)
                    .disabled(auth.authState == .authenticating)
            }
            
            // Reset Password button
            primaryButton(title: "Reset Password") {
                Task {
                    await auth.completePasswordReset(code: verificationCode, newPassword: newPassword)
                }
            }
            .disabled(verificationCode.isEmpty || newPassword.isEmpty || auth.authState == .authenticating)
            
            // Cancel button
            Button {
                auth.cancelAuthFlow()
                withAnimation { mode = .signIn }
                clearFields()
            } label: {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Sign in with Apple Button
    // TODO: Uncomment when Apple Developer Account is available
    /*
    private var signInWithAppleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            // Debug: Configure Apple Sign In request
            request.requestedScopes = [.email, .fullName]
            request.nonce = UUID().uuidString // Required for Clerk
            debugLog("AuthView: Apple Sign In request configured")
        } onCompletion: { result in
            // Debug: Handle Apple Sign In result
            switch result {
            case .success(let authorization):
                debugLog("AuthView: Apple Sign In success")
                if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    Task {
                        await auth.signInWithApple(credential: credential)
                    }
                }
            case .failure(let error):
                debugLog("AuthView: Apple Sign In failed - \(error.localizedDescription)")
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .cornerRadius(12)
    }
    */
    
    // MARK: - UI Components
    
    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
    
    private func dividerWithText(_ text: String) -> some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
    
    private func switchModeButton(text: String, action: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(text)
                    .foregroundStyle(.secondary)
                Text(action)
                    .foregroundStyle(.blue)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
        }
        .padding(.top, 8)
    }
    
    private func errorMessageView(_ error: String) -> some View {
        Text(error)
            .font(.caption)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
    }
    
    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(loadingText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
    
    private var loadingText: String {
        switch mode {
        case .signIn: return "Signing in..."
        case .register: return "Creating account..."
        case .verifyEmail: return "Verifying..."
        case .forgotPassword: return "Sending reset code..."
        case .resetPassword: return "Resetting password..."
        }
    }
    
    // MARK: - Helpers
    
    /// Clear all form fields
    /// Debug: Call when switching between modes
    private func clearFields() {
        email = ""
        username = ""
        password = ""
        confirmPassword = ""
        verificationCode = ""
        newPassword = ""
        auth.errorMessage = nil
        debugLog("AuthView: cleared form fields")
    }
    
    /// Handle auth state changes
    /// Debug: Switch modes based on auth state
    private func handleAuthStateChange(_ state: AuthState) {
        switch state {
        case .needsVerification(let email):
            debugLog("AuthView: needs verification for \(email)")
            if mode == .register {
                withAnimation { mode = .verifyEmail }
            } else if mode == .forgotPassword {
                withAnimation { mode = .resetPassword }
            }
            
        case .authenticated:
            debugLog("AuthView: authenticated, will be handled by parent")
            
        case .unauthenticated:
            debugLog("AuthView: unauthenticated")
            
        case .authenticating:
            debugLog("AuthView: authenticating...")
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
}
