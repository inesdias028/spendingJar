import Foundation
import Observation
import FirebaseFirestore

/// One person's data, kept in sync with Firebase. The screens update straight
/// away; Firebase saves in the background (and works offline).
@Observable
final class Store {
    let uid: String

    /// What you had (or owed) before you started tracking. Can be negative.
    var startBalance: Double = 0
    var categories: [Category] = defaultCategories + defaultIncomeCategories
    var recurring: [Recurring] = []
    /// Newest first.
    var entries: [Entry] = []

    /// True once the first data has arrived.
    var ready = false
    /// Set if Firebase refused or failed.
    var error: String?

    @ObservationIgnored private var userListener: ListenerRegistration?
    @ObservationIgnored private var entryListener: ListenerRegistration?
    @ObservationIgnored private var gotUser = false
    @ObservationIgnored private var gotEntries = false
    @ObservationIgnored private var ranRecurring = false

    private var userDoc: DocumentReference { Firestore.firestore().collection("users").document(uid) }
    private var entriesCol: CollectionReference { userDoc.collection("expenses") }

    init(uid: String) {
        self.uid = uid
        start()
    }

    deinit {
        userListener?.remove()
        entryListener?.remove()
    }

    // MARK: - Loading

    private func start() {
        userDoc.getDocument { [weak self] snap, err in
            guard let self else { return }
            if let err {
                self.fail(err)
                return
            }
            if snap?.exists != true { self.firstTimeSetup() }
            self.listen()
        }
    }

    /// A brand-new account (never used the web app either).
    private func firstTimeSetup() {
        userDoc.setData([
            "startBalance": 0,
            "recurring": [],
            "categories": (defaultCategories + defaultIncomeCategories).map(\.dict),
            "updatedAt": FieldValue.serverTimestamp(),
        ]) { [weak self] err in
            if let err { self?.fail(err) }
        }
    }

    private func listen() {
        userListener = userDoc.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err {
                self.fail(err)
                return
            }
            if let d = snap?.data() { self.apply(d) }
            self.gotUser = true
            self.maybeReady()
        }
        entryListener = entriesCol.addSnapshotListener { [weak self] query, err in
            guard let self else { return }
            if let err {
                self.fail(err)
                return
            }
            let docs = query?.documents ?? []
            self.entries = docs
                .compactMap { Entry(id: $0.documentID, $0.data()) }
                .sorted { $0.date > $1.date }
            self.gotEntries = true
            self.maybeReady()
        }
    }

    private func apply(_ d: [String: Any]) {
        startBalance = number(d["startBalance"]) ?? 0
        if let list = d["recurring"] as? [[String: Any]] {
            recurring = list.compactMap { Recurring($0) }
        }
        if let list = d["categories"] as? [[String: Any]] {
            categories = list.compactMap { Category($0) }
        }
        // Accounts from before income existed get the default income categories.
        if !categories.contains(where: { $0.income }) {
            categories += defaultIncomeCategories
        }
    }

    private func maybeReady() {
        guard gotUser && gotEntries else { return }
        ready = true
        if !ranRecurring {
            ranRecurring = true
            runRecurring()
        }
    }

    private func fail(_ err: Error) {
        error = err.localizedDescription
    }

    private func saveSettings() {
        userDoc.updateData([
            "startBalance": startBalance,
            "recurring": recurring.map(\.dict),
            "categories": categories.map(\.dict),
            "updatedAt": FieldValue.serverTimestamp(),
        ]) { [weak self] err in
            if let err { self?.fail(err) }
        }
    }

    // MARK: - Numbers

    /// Starting balance, plus all income, minus all spending.
    var balance: Double { entries.reduce(startBalance) { $0 + $1.signed } }

    /// Balance just before `date`.
    func balance(before date: Date) -> Double {
        entries.filter { $0.date < date }.reduce(startBalance) { $0 + $1.signed }
    }

    /// Money in and money out inside [from, to).
    func totals(from: Date, to: Date) -> (inc: Double, out: Double) {
        var inc = 0.0
        var out = 0.0
        for e in entries where e.date >= from && e.date < to {
            if e.income { inc += e.amount } else { out += e.amount }
        }
        return (inc, out)
    }

    func entries(from: Date, to: Date) -> [Entry] {
        entries.filter { $0.date >= from && $0.date < to }
    }

    func categories(income: Bool) -> [Category] { categories.filter { $0.income == income } }

    /// The category to show for an entry (falls back to its saved copy).
    func category(for e: Entry) -> Category {
        categories.first { $0.key == e.category }
            ?? Category(key: e.category, label: e.label ?? "Deleted", emoji: e.emoji ?? "🏷️", income: e.income)
    }

    /// A recurring item's own name, or the category's name.
    func title(for e: Entry) -> String {
        if e.isRecurring, let label = e.label, !label.isEmpty { return label }
        return category(for: e).label
    }

    // MARK: - Actions

    func addEntry(amount: Double, category c: Category, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = Entry(
            id: String(Int(Date().timeIntervalSince1970 * 1_000_000)),
            amount: amount,
            income: c.income,
            category: c.key,
            emoji: c.emoji,
            label: c.label,
            date: Date(),
            note: trimmed.isEmpty ? nil : trimmed
        )
        entries.insert(e, at: 0)
        entriesCol.document(e.id).setData(e.dict) { [weak self] err in
            if let err { self?.fail(err) }
        }
    }

    func deleteEntry(_ id: String) {
        entries.removeAll { $0.id == id }
        entriesCol.document(id).delete { [weak self] err in
            if let err { self?.fail(err) }
        }
    }

    func setStartBalance(_ v: Double) {
        startBalance = v
        saveSettings()
    }

    /// Returns an error message, or nil if the category was added.
    func addCategory(label: String, emoji: String, income: Bool) -> String? {
        let name = label.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return "Give your category a name" }
        if categories.contains(where: { $0.income == income && $0.label.lowercased() == name.lowercased() }) {
            return "You already have that category"
        }
        let e = emoji.trimmingCharacters(in: .whitespaces)
        categories.append(Category(
            key: "c\(Int(Date().timeIntervalSince1970 * 1000))",
            label: name,
            emoji: e.isEmpty ? (income ? "💰" : "🏷️") : e,
            income: income
        ))
        saveSettings()
        return nil
    }

    func deleteCategory(_ key: String) {
        categories.removeAll { $0.key == key }
        saveSettings()
    }

    func addRecurring(name: String, amount: Double, category c: Category, freq: Period, start: Date) {
        let s = dayStart(start)
        recurring.append(Recurring(
            id: String(Int(Date().timeIntervalSince1970 * 1000)),
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            income: c.income,
            category: c.key,
            emoji: c.emoji,
            label: c.label,
            freq: freq,
            anchorDay: cal.component(.day, from: s),
            next: s
        ))
        saveSettings()
        runRecurring()
    }

    func deleteRecurring(_ id: String) {
        recurring.removeAll { $0.id == id }
        saveSettings()
    }

    /// Adds any recurring money that has come due (up to today). Each date gets a
    /// fixed id, so two devices (or the web app) never add the same one twice.
    func runRecurring() {
        let today = dayStart(Date())
        var changed = false
        var updated: [Recurring] = []
        for r in recurring {
            var item = r
            var count = 0
            while item.next <= today && count < 500 {
                let d = item.next
                let id = "r_\(item.id)_\(ymdCompact(d))"
                let e = Entry(
                    id: id,
                    amount: item.amount,
                    income: item.income,
                    category: item.category,
                    emoji: item.emoji,
                    label: item.title,
                    date: cal.date(bySettingHour: 9, minute: 0, second: 0, of: d) ?? d,
                    note: nil
                )
                entriesCol.document(id).setData(e.dict)
                item.next = item.after(d)
                changed = true
                count += 1
            }
            updated.append(item)
        }
        if changed {
            recurring = updated
            saveSettings()
        }
    }
}
