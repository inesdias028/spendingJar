import SwiftUI

/// Where the privacy policy is published (GitHub Pages, from privacy.html).
let privacyPolicyURL = URL(string: "https://inesdias028.github.io/spendingJar/privacy.html")!

struct AccountView: View {
    @Environment(Store.self) private var store
    @Environment(AuthModel.self) private var auth
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var askPassword = false
    @State private var password = ""
    @State private var deleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(String(auth.email.prefix(1)).uppercased())
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(colors: [Color(white: 0.64), Color(white: 0.49)],
                                               startPoint: .top, endPoint: .bottom),
                                in: Circle()
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.email).font(.title3)
                            Text("Synced to your account")
                                .font(.footnote)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    NavigationLink {
                        StartBalanceView(isSheet: false)
                    } label: {
                        LabeledContent {
                            Text(signedEuro(store.startBalance))
                        } label: {
                            Label("Starting Balance", systemImage: "eurosign.circle.fill")
                        }
                    }
                    NavigationLink {
                        RecurringView()
                    } label: {
                        LabeledContent {
                            Text("\(store.recurring.count)")
                        } label: {
                            Label("Recurring", systemImage: "repeat.circle.fill")
                        }
                    }
                } header: {
                    Text("Balance")
                } footer: {
                    Text("Your entries are saved to your account, so they show up on any phone or computer where you sign in, including the Even website.")
                }

                Section {
                    Link(destination: privacyPolicyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) { confirmSignOut = true }
                        .frame(maxWidth: .infinity)
                }

                if !store.demo {
                    Section {
                        Button("Delete Account", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    } footer: {
                        Text("Deletes your account and all your entries, on the iPhone and on the website. This can\u{2019}t be undone.")
                    }
                }
            }
            .navigationTitle("Account")
            .disabled(deleting)
            .overlay {
                if deleting {
                    ProgressView("Deleting\u{2026}")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { auth.signOut() }
            }
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Account and All Data", role: .destructive) {
                    password = ""
                    askPassword = true
                }
            } message: {
                Text("Your balance, entries, categories and recurring items are deleted for good, on every device.")
            }
            .alert("Enter your password", isPresented: $askPassword) {
                SecureField("Password", text: $password)
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) { password = "" }
            } message: {
                Text("To keep your account safe, confirm it\u{2019}s you.")
            }
            .alert(
                "Couldn\u{2019}t delete the account",
                isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private func deleteAccount() async {
        let typed = password
        password = ""
        deleting = true
        defer { deleting = false }
        do {
            try await auth.deleteAccount(password: typed)
        } catch {
            deleteError = AuthModel.message(for: error)
        }
    }
}

/// How the balance is made up, and where you set what you started with.
struct StartBalanceView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let isSheet: Bool

    @State private var owed = false
    @State private var text = ""
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        let totals = store.totals(from: .distantPast, to: .distantFuture)
        let start = value ?? store.startBalance
        let total = start + totals.inc - totals.out

        Form {
            Section {
                VStack(spacing: 2) {
                    Text("Balance")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    Text(signedEuro(total))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.money(total))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            Section("How it adds up") {
                LabeledContent("Starting balance", value: signedEuro(start))
                LabeledContent("Money in") {
                    Text(signedEuro(totals.inc)).foregroundStyle(Color.green)
                }
                LabeledContent("Money out", value: euro(-totals.out))
            }

            Section {
                Picker("Starting balance", selection: $owed) {
                    Text("I had money (+)").tag(false)
                    Text("I owed money (−)").tag(true)
                }
                .pickerStyle(.segmented)
                HStack {
                    Text(owed ? "− €" : "+ €")
                        .foregroundStyle(owed ? Color.red : Color.green)
                    TextField("0", text: $text)
                        .keyboardType(.decimalPad)
                        .onChange(of: text) { _, _ in error = nil }
                }
            } header: {
                Text("Starting balance")
            } footer: {
                if let error {
                    Text(error).foregroundStyle(Color.red)
                } else {
                    Text("What you had (or owed) before you started using Even. Everything you add goes on top of it.")
                }
            }
        }
        .navigationTitle("Balance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear {
            if !loaded {
                loaded = true
                owed = store.startBalance < 0
                text = plainAmount(abs(store.startBalance))
            }
        }
    }

    /// The typed starting balance (0 when empty), or nil if it isn't a number.
    private var value: Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return 0 }
        guard let v = Double(t.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let rounded = (v * 100).rounded() / 100
        return owed ? -rounded : rounded
    }

    private func save() {
        guard let v = value else {
            error = "Type an amount, like 250 or 12,50."
            return
        }
        store.setStartBalance(v)
        dismiss()
    }
}

struct NewCategoryView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let income: Bool

    @State private var emoji = ""
    @State private var name = ""
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField(income ? "Emoji 💰" : "Emoji 🏷️", text: $emoji)
                TextField(income ? "Name, like Freelance" : "Name, like Gym", text: $name)
                    .textInputAutocapitalization(.sentences)
                    .onSubmit { save() }
            } footer: {
                if let error { Text(error).foregroundStyle(Color.red) }
            }

            Section("Suggestions") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(income ? suggestedIncomeEmojis : suggestedEmojis, id: \.self) { e in
                        Button {
                            emoji = e
                        } label: {
                            Text(e)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(
                                    emoji == e ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(income ? "New Income Type" : "New Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { save() }
            }
        }
    }

    private func save() {
        if let message = store.addCategory(label: name, emoji: emoji, income: income) {
            error = message
        } else {
            dismiss()
        }
    }
}
