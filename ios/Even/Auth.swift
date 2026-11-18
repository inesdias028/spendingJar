import Foundation
import Observation
import FirebaseCore
import FirebaseAuth

enum FirebaseSetup {
    /// Uses GoogleService-Info.plist if it was added to the project; otherwise the
    /// same public settings as the web app (lib/firebase_options.dart), so the
    /// app works with your existing account straight away.
    static func configure() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            return
        }
        let options = FirebaseOptions(googleAppID: "1:102458149662:web:75959c586fbf165c6cd70f",
                                      gcmSenderID: "102458149662")
        options.apiKey = "AIzaSyAr755xx0eOfCehPJpEUIsMUPqC52kBErM"
        options.projectID = "spending-jar"
        options.storageBucket = "spending-jar.firebasestorage.app"
        FirebaseApp.configure(options: options)
    }
}

/// Who is signed in, and the sign-in actions.
@Observable
final class AuthModel {
    var user: User?
    /// False until Firebase has said whether someone is signed in.
    var checked = false

    @ObservationIgnored private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.checked = true
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    var email: String { user?.email ?? "Unknown" }

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
        try? Auth.auth().signOut()
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
