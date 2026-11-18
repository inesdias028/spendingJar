import Foundation
import Observation
import FirebaseCore
import FirebaseAuth

enum FirebaseSetup {
    /// True once Firebase is set up for this app.
    private(set) static var isConfigured = false

    /// Firebase on iPhone needs the iOS app's own settings: GoogleService-Info.plist,
    /// downloaded from the Firebase console (Project settings → Your apps → iOS)
    /// and placed in ios/Even/. The web app's settings can't be used: Firebase
    /// stops the app at launch if the app ID isn't an iOS one.
    /// Without the file the app shows a message instead of crashing.
    @discardableResult
    static func configure() -> Bool {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return false }
        FirebaseApp.configure()
        isConfigured = true
        return true
    }
}

/// Who is signed in, and the sign-in actions.
@Observable
final class AuthModel {
    var user: User?
    /// False until Firebase has said whether someone is signed in.
    var checked = false

    @ObservationIgnored private var handle: AuthStateDidChangeListenerHandle?

    /// `active: false` when Firebase isn't set up (demo mode or missing settings).
    init(active: Bool) {
        guard active else {
            checked = true
            return
        }
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.checked = true
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    var email: String { user?.email ?? (Launch.demo ? "you@example.com" : "Unknown") }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func createAccount(email: String, password: String) async throws {
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func sendReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func signOut() {
        guard FirebaseSetup.isConfigured else { return }
        try? Auth.auth().signOut()
    }

    /// Deletes everything: first the data in Firestore, then the sign-in account.
    /// Firebase asks for a recent sign-in before deleting, so the password is checked again.
    func deleteAccount(password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw NSError(domain: "Even", code: 1, userInfo: [NSLocalizedDescriptionKey: "You're not signed in."])
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        _ = try await user.reauthenticate(with: credential)
        try await Store.deleteAllData(uid: user.uid)
        try await user.delete()
    }

    /// A friendly message for a Firebase sign-in error.
    static func message(for error: Error) -> String {
        switch (error as NSError).code {
        case 17008: return "That email address doesn't look right."
        case 17005: return "This account has been turned off."
        case 17009, 17011, 17004: return "Email or password is wrong. Try again or reset your password."
        case 17007: return "There is already an account with this email. Sign in instead."
        case 17026: return "Use at least 6 characters for your password."
        case 17010: return "Too many tries. Wait a few minutes and try again."
        case 17020: return "No internet connection. Connect and try again."
        case 17006: return "This sign-in method is not turned on in Firebase yet."
        default: return error.localizedDescription
        }
    }
}
