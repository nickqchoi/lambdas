//
//  AuthService.swift
//  lambdas-xi-chapter
//
//  Clerk-based authentication service. Supports:
//  - Email + password sign up with OTP verification
//  - Email/username + password sign in
//  - Sign in with Apple
//  - Password reset
//  Debug: All auth operations log state changes for troubleshooting
//

import Foundation
import Combine
import Clerk
// TODO: Uncomment when Apple Developer Account is available
// import AuthenticationServices

// MARK: - Auth State

/// Auth state for the app.
/// Debug: Track state transitions for debugging auth flows
enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case needsVerification(email: String)  // OTP verification needed
    case authenticated(User)
    
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated): return true
        case (.authenticating, .authenticating): return true
        case (.needsVerification(let e1), .needsVerification(let e2)): return e1 == e2
        case (.authenticated(let u1), .authenticated(let u2)): return u1.id == u2.id
        default: return false
        }
    }
}

// MARK: - Auth Service

/// Clerk-based authentication service.
/// Debug: Singleton pattern for app-wide auth state management
final class AuthService: ObservableObject {
    static let shared = AuthService()

    // MARK: - Published Properties
    
    @Published private(set) var authState: AuthState = .unauthenticated
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        debugLog("AuthService: init with Clerk")
        setupClerkObserver()
    }
    
    /// Setup observer for Clerk user changes
    /// Debug: Automatically updates authState when Clerk session changes
    private func setupClerkObserver() {
        // Observe Clerk user changes
        // Debug: This fires when user signs in/out or session refreshes
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkClerkSession()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Check current Clerk session and update auth state
    /// Debug: Called periodically to sync with Clerk state
    @MainActor
    private func checkClerkSession() {
        let clerk = Clerk.shared
        
        // If we're in the middle of verification, don't override
        if case .needsVerification = authState { return }
        if case .authenticating = authState { return }
        
        if let clerkUser = clerk.user {
            // User is signed in via Clerk
            let user = User(
                clerkId: clerkUser.id,
                username: clerkUser.username ?? "",
                email: clerkUser.primaryEmailAddress?.emailAddress ?? ""
            )
            
            if case .authenticated(let existingUser) = authState,
               existingUser.clerkId == user.clerkId {
                // Same user, no change needed
                return
            }
            
            // Refresh Supabase client to ensure it picks up the new Clerk session for RLS
            SupabaseConfig.refreshClient()
            
            // Cleanup previous realtime subscriptions to ensure a fresh start
            Task { @MainActor in
                await RealtimeService.shared.unsubscribeFromAll()
            }
            
            authState = .authenticated(user)
            debugLog("AuthService: Clerk session active for \(user.username)")
        } else if case .authenticated = authState {
            // Was authenticated but Clerk session ended
            authState = .unauthenticated
            debugLog("AuthService: Clerk session ended")
        }
    }
    
    // MARK: - Validation
    
    /// Validate email format
    /// Debug: Basic email validation
    private func validateEmail(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Email cannot be empty" }
        guard trimmed.contains("@") && trimmed.contains(".") else { 
            return "Please enter a valid email address" 
        }
        return nil
    }
    
    /// Validate username format
    /// Debug: Alphanumeric + underscores, 3-20 chars
    private func validateUsername(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Username cannot be empty" }
        guard trimmed.count >= 3 else { return "Username must be at least 3 characters" }
        guard trimmed.count <= 20 else { return "Username must be 20 characters or less" }
        
        // Allow alphanumeric and underscores only (Clerk limitation)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return "Username can only contain letters, numbers, and underscores"
        }
        
        return nil
    }
    
    /// Validate password format
    /// Debug: Minimum 8 characters for security
    private func validatePassword(_ password: String) -> String? {
        guard !password.isEmpty else { return "Password cannot be empty" }
        guard password.count >= 8 else { return "Password must be at least 8 characters" }
        return nil
    }

    // MARK: - Sign Up (Email + Password + Username)

    /// Register a new user with email, username, and password
    /// Debug: Creates Clerk user, then sends OTP for email verification
    func register(email: String, username: String, password: String, confirmPassword: String) async {
        debugLog("AuthService: register attempt for \(email), username: \(username)")
        
        // Validation
        if let error = validateEmail(email) {
            await MainActor.run { errorMessage = error }
            debugLog("AuthService: email validation failed - \(error)")
            return
        }
        
        if let error = validateUsername(username) {
            await MainActor.run { errorMessage = error }
            debugLog("AuthService: username validation failed - \(error)")
            return
        }
        
        if let error = validatePassword(password) {
            await MainActor.run { errorMessage = error }
            debugLog("AuthService: password validation failed - \(error)")
            return
        }
        
        guard password == confirmPassword else {
            await MainActor.run { errorMessage = "Passwords do not match" }
            debugLog("AuthService: passwords don't match")
            return
        }

        await MainActor.run { 
            errorMessage = nil 
            authState = .authenticating 
        }

        do {
            // Create sign-up with Clerk
            // Debug: This creates the user but requires email verification
            let signUp = try await SignUp.create(
                strategy: .standard(
                    emailAddress: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
            )
            
            debugLog("AuthService: signUp created, status: \(signUp.status)")
            
            // Set username on the user
            // Debug: Username is set after initial creation
            if !username.isEmpty {
                let params = SignUp.UpdateParams(username: username.trimmingCharacters(in: .whitespacesAndNewlines))
                try await signUp.update(params: params)
                debugLog("AuthService: username set to \(username)")
            }
            
            // Send verification email with OTP
            // Debug: User must enter this code to complete registration
            try await signUp.prepareVerification(strategy: .emailCode)
            debugLog("AuthService: verification email sent to \(email)")
            
            await MainActor.run {
                authState = .needsVerification(email: email)
            }
            
        } catch {
            await MainActor.run { 
                errorMessage = parseClerkError(error)
                authState = .unauthenticated
            }
            debugLog("AuthService: registration failed - \(error)")
        }
    }
    
    /// Verify email with OTP code
    /// Debug: Completes registration after user enters code from email
    func verifyEmail(code: String) async {
        debugLog("AuthService: verifying email with code")
        
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run { errorMessage = "Please enter the verification code" }
            return
        }
        
        await MainActor.run { 
            errorMessage = nil 
            authState = .authenticating 
        }
        
        do {
            // Get the in-progress sign-up
            guard let signUp = Clerk.shared.client?.signUp else {
                throw NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No sign-up in progress"])
            }
            
            // Attempt verification with the code
            // Debug: If successful, creates session and signs in user
            let result = try await signUp.attemptVerification(
                strategy: .emailCode(code: code.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            
            debugLog("AuthService: verification result status: \(result.status)")
            
            if result.status == .complete {
                // Registration complete, user is now signed in
                debugLog("AuthService: registration complete, user signed in")
                // The Clerk observer will pick up the new session
                await MainActor.run {
                    if let clerkUser = Clerk.shared.user {
                        let user = User(
                            clerkId: clerkUser.id,
                            username: clerkUser.username ?? "",
                            email: clerkUser.primaryEmailAddress?.emailAddress ?? ""
                        )
                        authState = .authenticated(user)
                    }
                }
            } else {
                debugLog("AuthService: verification incomplete, status: \(result.status)")
                await MainActor.run {
                    errorMessage = "Verification incomplete. Please try again."
                    authState = .unauthenticated
                }
            }
            
        } catch {
            await MainActor.run { 
                errorMessage = parseClerkError(error)
                authState = .unauthenticated
            }
            debugLog("AuthService: verification failed - \(error)")
        }
    }
    
    /// Resend verification code
    /// Debug: Call if user didn't receive or lost the original code
    func resendVerificationCode() async {
        debugLog("AuthService: resending verification code")
        
        do {
            guard let signUp = Clerk.shared.client?.signUp else {
                throw NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No sign-up in progress"])
            }
            
            try await signUp.prepareVerification(strategy: .emailCode)
            debugLog("AuthService: verification code resent")
            
            await MainActor.run {
                errorMessage = nil
            }
            
        } catch {
            await MainActor.run {
                errorMessage = parseClerkError(error)
            }
            debugLog("AuthService: resend failed - \(error)")
        }
    }

    // MARK: - Sign In (Email/Username + Password)

    /// Login with email or username and password
    /// Debug: Supports both email and username as identifier
    func login(identifier: String, password: String) async {
        debugLog("AuthService: login attempt for \(identifier)")
        
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedIdentifier.isEmpty else {
            await MainActor.run { errorMessage = "Please enter your email or username" }
            return
        }
        
        if let error = validatePassword(password) {
            await MainActor.run { errorMessage = error }
            return
        }

        await MainActor.run { 
            errorMessage = nil 
            authState = .authenticating 
        }

        do {
            // Create sign-in with Clerk
            // Debug: identifier can be email or username
            let signIn = try await SignIn.create(
                strategy: .identifier(trimmedIdentifier, password: password)
            )
            
            debugLog("AuthService: signIn created, status: \(signIn.status)")
            
            switch signIn.status {
            case .complete:
                // Sign-in successful
                debugLog("AuthService: login successful")
                await MainActor.run {
                    if let clerkUser = Clerk.shared.user {
                        let user = User(
                            clerkId: clerkUser.id,
                            username: clerkUser.username ?? "",
                            email: clerkUser.primaryEmailAddress?.emailAddress ?? ""
                        )
                        authState = .authenticated(user)
                    }
                }
                
            case .needsSecondFactor:
                // Second factor verification needed (e.g., new device)
                // Debug: Clerk's Client Trust may require OTP on new devices
                debugLog("AuthService: needs second factor verification")
                
                // Prepare email code for second factor
                // Debug: Email code second factor for Client Trust
                if let factors = signIn.supportedSecondFactors,
                   let emailAddressId = factors.first(where: { $0.strategy == "email_code" })?.emailAddressId {
                    do {
                        try await signIn.prepareSecondFactor(strategy: .emailCode(emailAddressId: emailAddressId))
                        
                        await MainActor.run {
                            let email = Clerk.shared.client?.signIn?.identifier ?? identifier
                            authState = .needsVerification(email: email)
                        }
                        debugLog("AuthService: second factor OTP sent")
                    } catch {
                        await MainActor.run {
                            errorMessage = "Failed to send verification code"
                            authState = .unauthenticated
                        }
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Additional verification required but not available"
                        authState = .unauthenticated
                    }
                }
                
            default:
                debugLog("AuthService: unexpected signIn status: \(signIn.status)")
                await MainActor.run {
                    errorMessage = "Login incomplete. Please try again."
                    authState = .unauthenticated
                }
            }
            
        } catch {
            await MainActor.run { 
                errorMessage = parseClerkError(error)
                authState = .unauthenticated
            }
            debugLog("AuthService: login failed - \(error)")
        }
    }
    
    /// Verify second factor with OTP code (for new device verification)
    /// Debug: Called when Clerk's Client Trust requires verification
    func verifySecondFactor(code: String) async {
        debugLog("AuthService: verifying second factor")
        
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run { errorMessage = "Please enter the verification code" }
            return
        }
        
        await MainActor.run {
            errorMessage = nil
            authState = .authenticating
        }
        
        do {
            guard let signIn = Clerk.shared.client?.signIn else {
                throw NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No sign-in in progress"])
            }
            
            let result = try await signIn.attemptSecondFactor(
                strategy: .emailCode(code: code.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            
            if result.status == .complete {
                debugLog("AuthService: second factor verified, login complete")
                await MainActor.run {
                    if let clerkUser = Clerk.shared.user {
                        let user = User(
                            clerkId: clerkUser.id,
                            username: clerkUser.username ?? "",
                            email: clerkUser.primaryEmailAddress?.emailAddress ?? ""
                        )
                        authState = .authenticated(user)
                    }
                }
            } else {
                await MainActor.run {
                    errorMessage = "Verification incomplete"
                    authState = .unauthenticated
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = parseClerkError(error)
                authState = .unauthenticated
            }
            debugLog("AuthService: second factor verification failed - \(error)")
        }
    }

    // MARK: - Sign in with Apple
    // TODO: Uncomment when Apple Developer Account is available
    /*
    /// Sign in with Apple using ASAuthorizationAppleIDCredential
    /// Debug: Handles Apple Sign In flow with Clerk
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        debugLog("AuthService: Sign in with Apple")
        
        await MainActor.run {
            errorMessage = nil
            authState = .authenticating
        }
        
        do {
            // Get the identity token from Apple credential
            guard let identityTokenData = credential.identityToken,
                  let idToken = String(data: identityTokenData, encoding: .utf8) else {
                throw NSError(domain: "AuthService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to get Apple ID token"])
            }
            
            debugLog("AuthService: got Apple ID token")
            
            // Authenticate with Clerk using the Apple ID token
            // Debug: This creates or signs in the user via Apple
            _ = try await SignIn.authenticateWithIdToken(
                provider: .apple,
                idToken: idToken
            )
            
            debugLog("AuthService: Apple sign-in completed")
            
            // Check if user is now signed in
            await MainActor.run {
                if let clerkUser = Clerk.shared.user {
                    let user = User(
                        clerkId: clerkUser.id,
                        username: clerkUser.username ?? clerkUser.firstName ?? "",
                        email: clerkUser.primaryEmailAddress?.emailAddress ?? ""
                    )
                    authState = .authenticated(user)
                    debugLog("AuthService: Apple sign-in successful for \(user.username)")
                } else {
                    errorMessage = "Apple sign-in incomplete"
                    authState = .unauthenticated
                    debugLog("AuthService: Apple sign-in failed - no user")
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = parseClerkError(error)
                authState = .unauthenticated
            }
            debugLog("AuthService: Apple sign-in failed - \(error)")
        }
    }
    */

    // MARK: - Password Reset

    /// Initiate password reset flow
    /// Debug: Sends reset email to user
    func resetPassword(email: String) async {
        debugLog("AuthService: password reset for \(email)")
        
        if let error = validateEmail(email) {
            await MainActor.run { errorMessage = error }
            return
        }
        
        await MainActor.run {
            errorMessage = nil
            authState = .authenticating
        }
        
        do {
            // Create a sign-in with the email identifier
            let signIn = try await SignIn.create(
                strategy: .identifier(email.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            
            // Get the email address ID from the sign-in object
            guard let emailAddressId = signIn.supportedFirstFactors?.first(where: { $0.strategy == "reset_password_email_code" })?.emailAddressId else {
                throw NSError(domain: "AuthService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Email address not found for password reset"])
            }
            
            // Request password reset code via first factor email code
            try await signIn.prepareFirstFactor(strategy: .resetPasswordEmailCode(emailAddressId: emailAddressId))
            
            debugLog("AuthService: password reset email sent")
            
            await MainActor.run {
                authState = .needsVerification(email: email)
            }
            
        } catch {
            await MainActor.run {
                errorMessage = parseClerkError(error)
                authState = .unauthenticated
            }
            debugLog("AuthService: password reset failed - \(error)")
        }
    }
    
    /// Complete password reset with code and new password
    /// Debug: Sets new password after OTP verification
    func completePasswordReset(code: String, newPassword: String) async {
        debugLog("AuthService: completing password reset")
        
        if let error = validatePassword(newPassword) {
            await MainActor.run { errorMessage = error }
            return
        }
        
        await MainActor.run {
            errorMessage = nil
            authState = .authenticating
        }
        
        do {
            guard let signIn = Clerk.shared.client?.signIn else {
                throw NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No password reset in progress"])
            }
            
            // Verify the code and set new password in one step
            let result = try await signIn.attemptFirstFactor(
                strategy: .resetPasswordEmailCode(
                    code: code.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            
            debugLog("AuthService: code verified, status: \(result.status)")
            
            // After verification, set the new password
            if result.status == .needsFirstFactor {
                // Now set the new password using resetPassword
                let resetParams = SignIn.ResetPasswordParams(password: newPassword)
                try await signIn.resetPassword(resetParams)
                debugLog("AuthService: new password set")
            }
            
            // Check if we're now signed in
            if result.status == .complete || Clerk.shared.session != nil {
                debugLog("AuthService: password reset complete, user signed in")
                await MainActor.run {
                    if let clerkUser = Clerk.shared.user {
                        let user = User(
                            clerkId: clerkUser.id,
                            username: clerkUser.username ?? "",
                            email: clerkUser.primaryEmailAddress?.emailAddress ?? ""
                        )
                        authState = .authenticated(user)
                    }
                }
            } else {
                await MainActor.run {
                    errorMessage = "Password reset incomplete"
                    authState = .unauthenticated
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = parseClerkError(error)
                authState = .unauthenticated
            }
            debugLog("AuthService: password reset completion failed - \(error)")
        }
    }

    // MARK: - Sign Out

    /// Sign out current user
    /// Debug: Clears Clerk session and resets app state
    func signOut() {
        debugLog("AuthService: signOut")
        
        Task { @MainActor in
            do {
                try await Clerk.shared.signOut()
                authState = .unauthenticated
                errorMessage = nil
                
                // Reset related services
                UnlockService.shared.resetUnlock()
                ProfileService.shared.clearCache()
                
                // Refresh Supabase client to clear any cached auth
                SupabaseConfig.refreshClient()
                
                debugLog("AuthService: signOut complete")
            } catch {
                debugLog("AuthService: signOut error - \(error)")
                // Force state reset even on error
                authState = .unauthenticated
            }
        }
    }
    
    /// Cancel current authentication flow
    /// Debug: Use to return to unauthenticated state from verification
    func cancelAuthFlow() {
        debugLog("AuthService: cancelling auth flow")
        Task { @MainActor in
            authState = .unauthenticated
            errorMessage = nil
        }
    }

    // MARK: - User Info

    /// Current authenticated user
    /// Debug: Returns nil if not signed in
    var currentUser: User? {
        if case .authenticated(let u) = authState { return u }
        return nil
    }
    
    /// Current Clerk user ID (for Supabase operations)
    /// Debug: This ID is used in RLS policies as auth.jwt() ->> 'sub'
    var currentClerkUserId: String? {
        currentUser?.clerkId
    }
    
    // MARK: - Error Parsing
    
    /// Parse Clerk error into user-friendly message
    /// Debug: Extracts readable message from Clerk error types
    private func parseClerkError(_ error: Error) -> String {
        let message = error.localizedDescription
        
        // Common Clerk error patterns
        if message.contains("password") && message.contains("weak") {
            return "Password is too weak. Use at least 8 characters with a mix of letters and numbers."
        }
        if message.contains("email") && message.contains("taken") {
            return "This email is already registered. Try signing in instead."
        }
        if message.contains("username") && message.contains("taken") {
            return "This username is already taken. Please choose another."
        }
        if message.contains("invalid") && message.contains("code") {
            return "Invalid verification code. Please check and try again."
        }
        if message.contains("expired") {
            return "Verification code expired. Please request a new one."
        }
        if message.contains("credentials") || message.contains("password") {
            return "Invalid email/username or password"
        }
        if message.contains("rate") || message.contains("limit") {
            return "Too many attempts. Please wait a moment and try again."
        }
        
        // Default to localized description
        return message.isEmpty ? "An error occurred. Please try again." : message
    }
}
