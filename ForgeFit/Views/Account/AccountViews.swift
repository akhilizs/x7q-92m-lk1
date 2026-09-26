import SwiftUI

extension CloudSync.Status {
    var text: String {
        switch self {
        case .idle: return "Signed in"
        case .syncing: return "Saving…"
        case .synced(let date):
            let seconds = Date().timeIntervalSince(date)
            if seconds < 60 { return "Progress saved · just now" }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Progress saved · \(formatter.localizedString(for: date, relativeTo: Date()))"
        case .failed(let message): return "Not saved yet: \(message)"
        }
    }
}

/// Log in or create an account.
struct AuthView: View {
    enum Mode {
        case logIn, signUp
    }

    @Environment(CloudSync.self) private var sync
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var mode: Mode
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var infoText: String?
    @FocusState private var focus: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        Group {
            if let conflict = sync.conflict {
                ConflictChoiceView(conflict: conflict, localWorkouts: store.sessions.count) { choice in
                    Task {
                        await sync.resolveConflict(choice)
                        dismiss()
                    }
                }
            } else {
                form
            }
        }
        .appBackground()
        .toolbar {
            if sync.conflict == nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(sync.conflict != nil || isWorking)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                BrandMark()
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    Text(mode == .logIn ? "Welcome\nback." : "Save your\nprogress.")
                        .font(.system(size: 34, weight: .light))
                        .lineSpacing(2)
                    Text(mode == .logIn
                         ? "Log in to bring your plans, workouts and progress to this iPhone."
                         : "Create a free account. Your plans, workouts, weigh-ins and coach chat are backed up and follow you to any iPhone.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 20)
                        TextField("Email", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focus, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focus = .password }
                            .accessibilityIdentifier("authEmail")
                    }
                    .authFieldStyle(focused: focus == .email)

                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 20)
                        SecureField(mode == .signUp ? "Password (6+ characters)" : "Password", text: $password)
                            .textContentType(mode == .signUp ? .newPassword : .password)
                            .focused($focus, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { submit() }
                            .accessibilityIdentifier("authPassword")
                    }
                    .authFieldStyle(focused: focus == .password)
                }

                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let infoText {
                    Label(infoText, systemImage: "envelope.badge")
                        .font(.footnote)
                        .foregroundStyle(Theme.sage)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    submit()
                } label: {
                    if isWorking {
                        ProgressView().tint(.black)
                    } else {
                        Text(mode == .logIn ? "Log in" : "Create account")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSubmit || isWorking)
                .opacity(canSubmit ? 1 : 0.5)

                if mode == .logIn {
                    Button("Forgot password?") { resetPassword() }
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .disabled(isWorking)
                }

                HStack(spacing: 4) {
                    Text(mode == .logIn ? "New here?" : "Already have an account?")
                        .foregroundStyle(Theme.textTertiary)
                    Button(mode == .logIn ? "Create an account" : "Log in") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mode = mode == .logIn ? .signUp : .logIn
                            errorText = nil
                            infoText = nil
                        }
                    }
                    .foregroundStyle(.white)
                }
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var canSubmit: Bool {
        email.contains("@") && email.contains(".") && password.count >= (mode == .signUp ? 6 : 1)
    }

    private func submit() {
        guard canSubmit, !isWorking else { return }
        focus = nil
        errorText = nil
        infoText = nil
        isWorking = true
        Task {
            do {
                switch mode {
                case .logIn:
                    try await sync.signIn(email: email, password: password)
                    Haptics.success()
                    if sync.conflict == nil { dismiss() }
                case .signUp:
                    if try await sync.signUp(email: email, password: password) {
                        Haptics.success()
                        if sync.conflict == nil { dismiss() }
                    } else {
                        infoText = "Almost done! Open the link we emailed to \(email.trimmingCharacters(in: .whitespaces)) to confirm your account, then log in here."
                        mode = .logIn
                        password = ""
                    }
                }
            } catch {
                errorText = error.localizedDescription
                Haptics.warning()
            }
            isWorking = false
        }
    }

    private func resetPassword() {
        guard email.contains("@") else {
            errorText = "Enter your email above first."
            focus = .email
            return
        }
        errorText = nil
        isWorking = true
        Task {
            do {
                try await sync.sendPasswordReset(email: email)
                infoText = "Check your email for a link to choose a new password."
            } catch {
                errorText = error.localizedDescription
            }
            isWorking = false
        }
    }
}

private extension View {
    func authFieldStyle(focused: Bool) -> some View {
        self
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(focused ? Color.white.opacity(0.5) : Theme.stroke, lineWidth: 1)
            )
    }
}

/// Shown on first login when this iPhone and the account both have progress.
struct ConflictChoiceView: View {
    let conflict: CloudSync.Conflict
    let localWorkouts: Int
    let onChoose: (CloudSync.ConflictChoice) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                IconBadge(symbol: "arrow.triangle.2.circlepath", size: 52)
                    .padding(.top, 12)
                VStack(alignment: .leading, spacing: 10) {
                    Text("You have progress\nin two places.")
                        .font(.system(size: 32, weight: .light))
                        .lineSpacing(2)
                    Text("Your account has \(count(conflict.remote.sessions.count)), last saved \(savedDate). This iPhone has \(count(localWorkouts)) that aren't in your account yet.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 12) {
                    choice("Combine both", detail: "Keeps every workout, weigh-in and plan from both. Recommended.",
                           symbol: "square.stack.3d.up.fill", highlighted: true) { onChoose(.combine) }
                    choice("Use my account's progress", detail: "Replaces what's on this iPhone.",
                           symbol: "icloud.and.arrow.down") { onChoose(.useAccount) }
                    choice("Keep this iPhone's progress", detail: "Replaces what's saved in your account.",
                           symbol: "iphone") { onChoose(.useThisDevice) }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var savedDate: String {
        let date = Date(timeIntervalSince1970: conflict.remoteSavedAt)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func count(_ workouts: Int) -> String {
        workouts == 1 ? "1 workout" : "\(workouts) workouts"
    }

    private func choice(_ title: String, detail: String, symbol: String, highlighted: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(highlighted ? Color.black.opacity(0.08) : Theme.surfaceRaised))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .medium))
                    Text(detail)
                        .font(.caption)
                        .opacity(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(highlighted ? Theme.ink : .white)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(highlighted ? AnyShapeStyle(Theme.paper) : AnyShapeStyle(Theme.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(highlighted ? Color.clear : Theme.stroke)
            )
        }
        .buttonStyle(PressableStyle())
    }
}

/// The signed-in account: sync status, password, log out and delete.
struct AccountView: View {
    @Environment(CloudSync.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @State private var confirmSignOut = false
    @State private var confirmForceSignOut = false
    @State private var confirmDelete = false
    @State private var showPassword = false
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Image(systemName: statusSymbol)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 68, height: 68)
                        .background(Circle().fill(Theme.sage))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sync.session?.email ?? "")
                            .font(.system(size: 18, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        TimelineView(.periodic(from: .now, by: 30)) { _ in
                            Text(sync.status.text)
                                .font(.footnote)
                                .foregroundStyle(isFailed ? Theme.danger : Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 8)

                Button {
                    Task { await sync.sync() }
                } label: {
                    Label(sync.status == .syncing ? "Saving…" : "Sync now", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(sync.status == .syncing)

                VStack(alignment: .leading, spacing: 8) {
                    Label("What's saved", systemImage: "icloud")
                        .font(.subheadline.weight(.medium))
                    Text("Your profile, plans, workouts, weigh-ins and coach chat are saved to your account automatically and come back when you log in on any iPhone. Your Gemini API key stays on this iPhone.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                Button {
                    showPassword = true
                } label: {
                    Label("Change password", systemImage: "key")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    confirmSignOut = true
                } label: {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(SecondaryButtonStyle())

                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                }

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Text("Delete account")
                        .font(.subheadline)
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().strokeBorder(Theme.danger.opacity(0.4)))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .disabled(isWorking)
        }
        .appBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .resumeWorkoutBar()
        .sheet(isPresented: $showPassword) {
            NavigationStack { SetPasswordView() }
                .environment(sync)
        }
        .confirmationDialog("Log out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Log out", role: .destructive) { signOut(force: false) }
        } message: {
            Text("Your progress stays saved in your account. This iPhone is cleared so someone else can log in.")
        }
        .alert("Some changes aren't saved yet", isPresented: $confirmForceSignOut) {
            Button("Log out anyway", role: .destructive) { signOut(force: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They couldn't be uploaded (you may be offline). If you log out now, they'll be lost.")
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { deleteAccount() }
        } message: {
            Text("Your account and the progress saved in it are permanently deleted. This iPhone keeps its data.")
        }
    }

    private var isFailed: Bool {
        if case .failed = sync.status { return true }
        return false
    }

    private var statusSymbol: String {
        switch sync.status {
        case .failed: return "exclamationmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        default: return "checkmark.icloud"
        }
    }

    private func signOut(force: Bool) {
        isWorking = true
        Task {
            if await sync.signOut(force: force) {
                Haptics.success()
            } else {
                confirmForceSignOut = true
            }
            isWorking = false
        }
    }

    private func deleteAccount() {
        isWorking = true
        errorText = nil
        Task {
            do {
                try await sync.deleteAccount()
                Haptics.success()
                dismiss()
            } catch {
                errorText = error.localizedDescription
                Haptics.warning()
            }
            isWorking = false
        }
    }
}

/// Choose a new password (after a reset link, or from the account screen).
struct SetPasswordView: View {
    @Environment(CloudSync.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirm = ""
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose a new\npassword.")
                        .font(.system(size: 32, weight: .light))
                        .lineSpacing(2)
                    Text(sync.session.map { "For \($0.email)" } ?? "")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.top, 8)
                SecureField("New password (6+ characters)", text: $password)
                    .textContentType(.newPassword)
                    .authFieldStyle(focused: false)
                SecureField("Repeat new password", text: $confirm)
                    .textContentType(.newPassword)
                    .authFieldStyle(focused: false)
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                }
                Button {
                    save()
                } label: {
                    if isWorking { ProgressView().tint(.black) } else { Text("Save password") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(password.count < 6 || isWorking)
                .opacity(password.count < 6 ? 0.5 : 1)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .appBackground()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    sync.isResettingPassword = false
                    dismiss()
                }
            }
        }
    }

    private func save() {
        guard password == confirm else {
            errorText = "The passwords don't match."
            return
        }
        errorText = nil
        isWorking = true
        Task {
            do {
                try await sync.updatePassword(password)
                Haptics.success()
                dismiss()
            } catch {
                errorText = error.localizedDescription
                Haptics.warning()
            }
            isWorking = false
        }
    }
}
