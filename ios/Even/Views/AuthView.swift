import SwiftUI

/// Sign in / create account.
struct AuthView: View {
    @Environment(AuthModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var creating = false
    @State private var busy = false
    @State private var error: String?
    @State private var info: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("Logo")
                    .resizable()
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
                    .padding(.top, 40)

                VStack(spacing: 4) {
                    Text("Even").font(.largeTitle.bold())
                    Text(creating ? "Create your account" : "Sign in to see your balance")
                        .foregroundStyle(Color.secondary)
                }

                VStack(spacing: 0) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                    Divider().padding(.leading)
                    SecureField("Password", text: $password)
                        .textContentType(creating ? .newPassword : .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await submit() } }
                        .padding()
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if !creating {
                    Button("Forgot password?") { Task { await reset() } }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .disabled(busy)
                }

                if let error { Notice(text: error, color: .red) }
                if let info { Notice(text: info, color: .green) }

                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if busy {
                            ProgressView().tint(Color.white)
                        } else {
                            Text(creating ? "Create Account" : "Sign In").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(busy)

                Text("Signed up with Google on the website? Type your email above and tap \u{201C}Forgot password?\u{201D} to set a password, then sign in here.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)

                Button(creating ? "Already have an account? Sign in" : "New here? Create an account") {
                    creating.toggle()
                    error = nil
                    info = nil
                }
                .font(.subheadline)
                .disabled(busy)
            }
            .padding(24)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
    }

    private func submit() async {
        let mail = email.trimmingCharacters(in: .whitespaces)
        guard mail.contains("@") else { error = "Enter your email address."; return }
        guard !password.isEmpty else { error = "Enter your password."; return }
        if creating && password.count < 6 { error = "Use at least 6 characters for your password."; return }
        busy = true
        error = nil
        info = nil
        defer { busy = false }
        do {
            if creating {
                try await auth.createAccount(email: mail, password: password)
            } else {
                try await auth.signIn(email: mail, password: password)
            }
        } catch {
            self.error = AuthModel.message(for: error)
        }
    }

    private func reset() async {
        let mail = email.trimmingCharacters(in: .whitespaces)
        guard mail.contains("@") else {
            error = "Type your email above first, then tap \u{201C}Forgot password?\u{201D} again."
            return
        }
        busy = true
        error = nil
        info = nil
        defer { busy = false }
        do {
            try await auth.sendReset(email: mail)
            info = "We sent a reset link to \(mail). Check your inbox."
        } catch {
            self.error = AuthModel.message(for: error)
        }
    }
}

private struct Notice: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
