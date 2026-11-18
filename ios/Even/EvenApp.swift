import SwiftUI

@main
struct EvenApp: App {
    @State private var auth: AuthModel

    init() {
        let ready = FirebaseSetup.configure()
        _auth = State(initialValue: AuthModel(active: ready))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
    }
}

/// Launch arguments, used for testing: "-demo" opens sample data without signing
/// in, "-tab stats" / "-tab account" picks the first tab, "-signin" forces the
/// sign-in screen.
enum Launch {
    static let args = ProcessInfo.processInfo.arguments
    static var demo: Bool { args.contains("-demo") }
    static var forceSignIn: Bool { args.contains("-signin") }
    static var showRecurring: Bool { args.contains("-recurring") }
    static var editCategories: Bool { args.contains("-editcategories") }
    static var tab: Int {
        guard let i = args.firstIndex(of: "-tab"), i + 1 < args.count else { return 0 }
        switch args[i + 1] {
        case "stats": return 1
        case "account": return 2
        default: return 0
        }
    }
}

/// Sign-in screen when signed out, the app when signed in.
struct RootView: View {
    @Environment(AuthModel.self) private var auth
    @State private var demoStore: Store? = Launch.demo ? Store.demoStore() : nil

    var body: some View {
        Group {
            if let demoStore {
                MainTabs().environment(demoStore)
            } else if !FirebaseSetup.isConfigured {
                ContentUnavailableView {
                    Label("Firebase isn't set up yet", systemImage: "gearshape.2")
                } description: {
                    Text("This copy of Even was built without GoogleService-Info.plist. Add it to ios/Even/ (Firebase console → Project settings → Your apps → iOS) and build again.")
                }
            } else if Launch.forceSignIn {
                AuthView()
            } else if !auth.checked {
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
    @State private var tab = Launch.tab

    var body: some View {
        TabView(selection: $tab) {
            BalanceView()
                .tabItem { Label("Balance", systemImage: "creditcard") }
                .tag(0)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(1)
            AccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
                .tag(2)
        }
    }
}
