import SwiftUI

@main
struct EvenApp: App {
    @State private var auth: AuthModel

    init() {
        FirebaseSetup.configure()
        _auth = State(initialValue: AuthModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
    }
}

/// Sign-in screen when signed out, the app when signed in.
struct RootView: View {
    @Environment(AuthModel.self) private var auth

    var body: some View {
        Group {
            if !auth.checked {
                ProgressView()
            } else if let user = auth.user {
                SignedInView(uid: user.uid)
                    .id(user.uid)
            } else {
                AuthView()
            }
        }
    }
}

struct SignedInView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: Store

    init(uid: String) {
        _store = State(initialValue: Store(uid: uid))
    }

    var body: some View {
        Group {
            if let message = store.error {
                ContentUnavailableView {
                    Label("Couldn't load your data", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Sign Out") { auth.signOut() }
                }
            } else if !store.ready {
                ProgressView()
            } else {
                MainTabs()
            }
        }
        .environment(store)
        // Coming back to the app: add any recurring money that is now due.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && store.ready { store.runRecurring() }
        }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            BalanceView()
                .tabItem { Label("Balance", systemImage: "creditcard") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            AccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
    }
}
