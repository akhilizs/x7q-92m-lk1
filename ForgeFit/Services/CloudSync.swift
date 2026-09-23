import Foundation
import Observation

/// Keeps the user's progress saved to their account.
///
/// Local-first: the app always works on its own copy on the device. While signed in,
/// changes are uploaded a few seconds after they happen, and the account's copy is
/// checked whenever the app opens. If another device saved in the meantime, the two
/// copies are combined so no workout, weigh-in, plan or message is lost.
@Observable
@MainActor
final class CloudSync {
    enum Status: Equatable {
        case idle
        case syncing
        case synced(Date)
        case failed(String)
    }

    /// Both this iPhone and the account already have progress on first login.
    struct Conflict {
        let remote: AppStore.Snapshot
        let remoteSavedAt: Double
    }

    enum ConflictChoice {
        case combine, useAccount, useThisDevice
    }

    private(set) var session: AuthSession?
    private(set) var status: Status = .idle
    private(set) var conflict: Conflict?
    /// Set when a password-reset link opened the app; the UI asks for a new password.
    var isResettingPassword = false
    /// A one-off message for the user, such as the result of an email link.
    var notice: String?

    var isConfigured: Bool { client != nil }
    var isSignedIn: Bool { session != nil }

    /// Delay between a change and its upload, so a burst of edits goes up together.
    @ObservationIgnored var uploadDelay: TimeInterval = 3
    @ObservationIgnored private let client: SupabaseClient?
    @ObservationIgnored private weak var store: AppStore?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var uploadTask: Task<Void, Never>?
    @ObservationIgnored private var applyingRemote = false
    @ObservationIgnored private var isSyncing = false
    @ObservationIgnored private var syncAgain = false
    @ObservationIgnored private var changeCount = 0

    init(client: SupabaseClient? = SupabaseConfig.current.map { SupabaseClient(config: $0) },
         defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        session = client == nil ? nil : KeychainStore.authSession
    }

    /// `savedAt` of the account copy this device last matched.
    private var lastSavedAt: Double {
        get { defaults.double(forKey: "cloud.lastSavedAt") }
        set { defaults.set(newValue, forKey: "cloud.lastSavedAt") }
    }

    /// Local changes that haven't been uploaded yet (survives the app being closed).
    private(set) var hasLocalChanges: Bool {
        get { defaults.bool(forKey: "cloud.pendingChanges") }
        set { defaults.set(newValue, forKey: "cloud.pendingChanges") }
    }

    func attach(_ store: AppStore) {
        self.store = store
        store.onChange = { [weak self] in
            MainActor.assumeIsolated { self?.localDidChange() }
        }
    }

    // MARK: Account

    /// Creates an account and starts saving to it. Returns `false` when the user has to
    /// confirm their email first.
    func signUp(email: String, password: String) async throws -> Bool {
        guard let client else { return false }
        guard let newSession = try await client.signUp(email: Self.clean(email), password: password) else { return false }
        await begin(newSession)
        return true
    }

    func signIn(email: String, password: String) async throws {
        guard let client else { return }
        await begin(try await client.signIn(email: Self.clean(email), password: password))
    }

    func sendPasswordReset(email: String) async throws {
        try await client?.sendPasswordReset(email: Self.clean(email))
    }

    func updatePassword(_ password: String) async throws {
        guard let client else { return }
        try await authorized { try await client.updatePassword(password, session: $0) }
        isResettingPassword = false
    }

    /// Handles a confirmation or password-reset link that opened the app.
    func handleCallback(_ url: URL) async {
        guard let client, url.host == "auth-callback" else { return }
        do {
            let (newSession, type) = try await client.session(fromCallback: url)
            if newSession.userID == session?.userID {
                setSession(newSession)
            } else {
                await begin(newSession)
            }
            if type == "recovery" {
                isResettingPassword = true
            } else {
                notice = "Your email is confirmed and you're logged in."
            }
        } catch {
            notice = error.localizedDescription
        }
    }

    /// Uploads pending changes, logs out and clears this iPhone so someone else can log in.
    /// Returns `false` (and stays logged in) if changes couldn't be uploaded, unless `force`.
    @discardableResult
    func signOut(force: Bool = false) async -> Bool {
        guard let client, let current = session else { return true }
        if hasLocalChanges {
            uploadTask?.cancel()
            await sync()
            if hasLocalChanges && !force { return false }
        }
        uploadTask?.cancel()
        await client.signOut(current)
        forgetAccount()
        applyingRemote = true
        store?.resetAll()
        applyingRemote = false
        return true
    }

    /// Permanently deletes the account and its cloud copy. This iPhone keeps its data.
    func deleteAccount() async throws {
        guard let client else { return }
        try await authorized { try await client.deleteAccount($0) }
        uploadTask?.cancel()
        forgetAccount()
    }

    func resolveConflict(_ choice: ConflictChoice) async {
        guard let conflict, let store else { return }
        self.conflict = nil
        switch choice {
        case .combine:
            applyRemote(SyncMerge.merge(local: store.makeSnapshot(), remote: conflict.remote, preferLocal: true))
        case .useAccount:
            applyRemote(conflict.remote)
            lastSavedAt = conflict.remoteSavedAt
            hasLocalChanges = false
            status = .synced(Date())
            return
        case .useThisDevice:
            break
        }
        status = .syncing
        do { try await upload() } catch { handle(error) }
    }

    // MARK: Syncing

    /// Brings this device and the account up to date: downloads newer progress saved
    /// from another device (combining it with local changes if both changed) and
    /// uploads local changes.
    func sync() async {
        guard client != nil, session != nil, conflict == nil, store != nil else { return }
        if isSyncing {
            syncAgain = true
            return
        }
        isSyncing = true
        repeat {
            syncAgain = false
            await syncOnce()
        } while syncAgain && session != nil && conflict == nil
        isSyncing = false
    }

    private func syncOnce() async {
        guard let client, let store else { return }
        status = .syncing
        do {
            let remote = try await authorized { try await client.fetchSave($0) }
            if let remote, remote.savedAt > lastSavedAt + 0.0005, let snapshot = AppStore.decode(remote.snapshot) {
                if hasLocalChanges || lastSavedAt == 0 {
                    // Both sides changed: keep everything from both, then upload the result.
                    applyRemote(SyncMerge.merge(local: store.makeSnapshot(), remote: snapshot, preferLocal: true))
                    try await upload()
                } else {
                    applyRemote(snapshot)
                    lastSavedAt = remote.savedAt
                    status = .synced(Date())
                }
            } else if hasLocalChanges || (remote == nil && store.hasOnboarded) {
                try await upload()
            } else {
                status = .synced(Date())
            }
        } catch {
            handle(error)
        }
    }

    /// First sync after logging in: download the account's progress, upload this
    /// iPhone's, or ask when both have some.
    private func firstSync() async {
        guard let client, let store else { return }
        status = .syncing
        do {
            let remote = try await authorized { try await client.fetchSave($0) }
            guard let remote, let snapshot = AppStore.decode(remote.snapshot) else {
                // Nothing in the account yet: it starts with what's on this iPhone.
                if store.hasOnboarded { try await upload() } else { status = .synced(Date()) }
                return
            }
            if !store.hasOnboarded {
                applyRemote(snapshot)
                lastSavedAt = remote.savedAt
                status = .synced(Date())
            } else if !store.hasProgress {
                // Only onboarding answers here: take the account's progress, keep any new plan.
                applyRemote(SyncMerge.merge(local: store.makeSnapshot(), remote: snapshot, preferLocal: false))
                try await upload()
            } else {
                conflict = Conflict(remote: snapshot, remoteSavedAt: remote.savedAt)
                status = .idle
            }
        } catch {
            handle(error)
        }
    }

    private func localDidChange() {
        guard session != nil, !applyingRemote else { return }
        changeCount += 1
        hasLocalChanges = true
        uploadTask?.cancel()
        let delay = uploadDelay
        uploadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    private func upload() async throws {
        guard let client, let store else { return }
        let startCount = changeCount
        let savedAt = (Date().timeIntervalSince1970 * 1000).rounded() / 1000
        let save = CloudSave(savedAt: savedAt, snapshot: try AppStore.encode(store.makeSnapshot()))
        try await authorized { try await client.upload(save, session: $0) }
        lastSavedAt = savedAt
        if changeCount == startCount { hasLocalChanges = false }
        status = .synced(Date())
    }

    private func applyRemote(_ snapshot: AppStore.Snapshot) {
        applyingRemote = true
        store?.apply(snapshot)
        applyingRemote = false
    }

    // MARK: Session

    private func begin(_ newSession: AuthSession) async {
        setSession(newSession)
        lastSavedAt = 0
        hasLocalChanges = false
        conflict = nil
        notice = nil
        await firstSync()
    }

    /// Runs `operation` with a valid access token, refreshing it when needed.
    private func authorized<T>(_ operation: (AuthSession) async throws -> T) async throws -> T {
        guard let client, var current = session else {
            throw SupabaseError(status: 401, code: "session_expired", message: "You're not logged in.")
        }
        if current.needsRefresh {
            current = try await refreshed(current, client: client)
        }
        do {
            return try await operation(current)
        } catch let error as SupabaseError where error.isUnauthorized {
            current = try await refreshed(current, client: client)
            return try await operation(current)
        }
    }

    private func refreshed(_ current: AuthSession, client: SupabaseClient) async throws -> AuthSession {
        do {
            let fresh = try await client.refresh(current)
            setSession(fresh)
            return fresh
        } catch let error as SupabaseError where [400, 401, 403].contains(error.status ?? 0) {
            // The login is no longer valid: stop syncing but keep everything on this iPhone.
            forgetAccount()
            let expired = SupabaseError(status: 401, code: "session_expired", message: error.message)
            notice = expired.localizedDescription
            throw expired
        }
    }

    private func setSession(_ newValue: AuthSession?) {
        session = newValue
        KeychainStore.authSession = newValue
    }

    private func forgetAccount() {
        setSession(nil)
        lastSavedAt = 0
        hasLocalChanges = false
        conflict = nil
        status = .idle
    }

    private func handle(_ error: Error) {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            status = .idle
        } else if session == nil {
            status = .idle
        } else {
            status = .failed(error.localizedDescription)
        }
    }

    private static func clean(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Combines two copies of the app's data without losing workouts, weigh-ins, plans or messages.
enum SyncMerge {
    /// `preferLocal` decides whose profile, active plan and in-progress workout win.
    static func merge(local: AppStore.Snapshot, remote: AppStore.Snapshot, preferLocal: Bool) -> AppStore.Snapshot {
        let primary = preferLocal ? local : remote
        let secondary = preferLocal ? remote : local
        var result = primary
        result.hasOnboarded = local.hasOnboarded || remote.hasOnboarded
        if !primary.hasOnboarded && secondary.hasOnboarded {
            result.profile = secondary.profile
        }
        result.plans = union(primary.plans, secondary.plans)
        result.sessions = union(primary.sessions, secondary.sessions).sorted { $0.startedAt > $1.startedAt }
        result.bodyWeights = union(primary.bodyWeights, secondary.bodyWeights).sorted { $0.date < $1.date }
        result.chatMessages = union(primary.chatMessages, secondary.chatMessages).sorted { $0.date < $1.date }
        if result.chatHistory.isEmpty {
            result.chatHistory = secondary.chatHistory
        }
        if let latest = result.bodyWeights.last {
            result.profile.bodyWeightKg = latest.weightKg
        }
        // A workout still running here but already finished on the other device.
        if let active = result.activeSession, result.sessions.contains(where: { $0.id == active.id }) {
            result.activeSession = nil
        }
        if !result.plans.contains(where: { $0.id == result.activePlanID }) {
            let fallback = secondary.activePlanID.flatMap { id in result.plans.contains { $0.id == id } ? id : nil }
            result.activePlanID = fallback ?? result.plans.first?.id
        }
        return result
    }

    private static func union<T: Identifiable>(_ first: [T], _ second: [T]) -> [T] {
        var seen = Set(first.map(\.id))
        return first + second.filter { seen.insert($0.id).inserted }
    }
}
