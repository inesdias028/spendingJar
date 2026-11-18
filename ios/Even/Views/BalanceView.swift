import SwiftUI

struct BalanceView: View {
    @Environment(Store.self) private var store

    @State private var amountText = ""
    @State private var note = ""
    @State private var income = false
    @State private var repeatFreq: Period?
    /// How many entries the activity list shows; "Show More" adds another page.
    @State private var shown = 40
    @State private var showStartBalance = false
    @State private var showRecurring = false
    @State private var showNewCategory = false
    @State private var pendingDelete: Entry?
    @State private var toast: String?
    @State private var addedCount = 0
    @FocusState private var focus: Field?

    private enum Field { case amount, note }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BalanceCard()
                        .contentShape(Rectangle())
                        .onTapGesture { showStartBalance = true }
                }

                newEntrySection
                categorySection
                activitySections
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Balance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRecurring = true
                    } label: {
                        Image(systemName: "repeat")
                    }
                    .accessibilityLabel("Recurring")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
            .sheet(isPresented: $showStartBalance) {
                NavigationStack { StartBalanceView(isSheet: true) }
            }
            .sheet(isPresented: $showRecurring) {
                NavigationStack {
                    RecurringView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showRecurring = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showNewCategory) {
                NavigationStack { NewCategoryView(income: income) }
            }
            .alert(
                "Delete \(signedEuro(pendingDelete?.signed ?? 0))?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                presenting: pendingDelete
            ) { entry in
                Button("Delete", role: .destructive) { store.deleteEntry(entry.id) }
                Button("Cancel", role: .cancel) {}
            } message: { entry in
                Text(deleteMessage(entry))
            }
            .overlay(alignment: .top) {
                if let toast { Toast(text: toast) }
            }
            .sensoryFeedback(.success, trigger: addedCount)
        }
    }

    // MARK: Sections

    private var newEntrySection: some View {
        Section("New entry") {
            Picker("Type", selection: $income) {
                Text("Spending").tag(false)
                Text("Income").tag(true)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Text(income ? "+ €" : "− €")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(income ? Color.green : Color.secondary)
                TextField("0,00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(income ? Color.green : Color.primary)
                    .focused($focus, equals: .amount)
            }
            .padding(.vertical, 4)

            // Optional reason for the amount ("Dinner with Ana").
            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .foregroundStyle(Color.secondary)
                TextField(income ? "Note (optional), like Birthday money" : "Note (optional), like Dinner with Ana",
                          text: $note)
                    .focused($focus, equals: .note)
                    .submitLabel(.done)
                    .onSubmit { focus = nil }
            }

            Picker("Repeat", selection: $repeatFreq) {
                Text("Never").tag(Period?.none)
                ForEach(Period.allCases) { p in
                    Text(p.freqName).tag(Period?.some(p))
                }
            }
        }
    }

    private var categorySection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(store.categories(income: income)) { c in
                    Button {
                        add(c)
                    } label: {
                        CategoryTile(emoji: c.emoji, label: c.label)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteCategory(c.key)
                        } label: {
                            Label("Delete Category", systemImage: "trash")
                        }
                    }
                }
                Button {
                    showNewCategory = true
                } label: {
                    CategoryTile(emoji: nil, label: "New")
                }
                .buttonStyle(.plain)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text(repeatFreq != nil ? "Tap a category to make it repeat"
                 : income ? "Tap where the money came from" : "Tap a category to add")
        } footer: {
            Text("Touch and hold a category to delete it.")
        }
    }

    @ViewBuilder
    private var activitySections: some View {
        let items = Array(store.entries.prefix(shown))
        let groups = Dictionary(grouping: items) { dayStart($0.date) }
            .map { DayGroup(id: $0.key, entries: $0.value) }
            .sorted { $0.id > $1.id }

        if items.isEmpty {
            Section("Activity") {
                ContentUnavailableView("Nothing yet", systemImage: "tray",
                                       description: Text("Add your first entry above."))
            }
        } else {
            ForEach(groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        EntryRow(entry: entry)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDelete = entry
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(dayHeading(group.id))
                        Spacer()
                        Text(signedEuro(group.entries.reduce(0) { $0 + $1.signed }))
                    }
                }
            }
            if store.entries.count > items.count {
                Section {
                    Button("Show More") { shown += 40 }
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Actions

    private func add(_ c: Category) {
        guard let amount = parseAmount(amountText) else {
            showToast("Type an amount first, like 4,50")
            focus = .amount
            return
        }
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let freq = repeatFreq {
            // For something that repeats, the note becomes its name (e.g. "Netflix").
            store.addRecurring(name: n, amount: amount, category: c, freq: freq, start: Date())
            showToast("\(n.isEmpty ? c.label : n) repeats \(freq.freqName.lowercased()) from today")
        } else {
            store.addEntry(amount: amount, category: c, note: n)
            showToast("\(c.emoji) \(n.isEmpty ? c.label : n)  \(signedEuro(c.income ? amount : -amount))")
        }
        amountText = ""
        note = ""
        repeatFreq = nil
        focus = nil
        addedCount += 1
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(duration: 0.3)) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) {
                if toast == text { toast = nil }
            }
        }
    }

    private func deleteMessage(_ e: Entry) -> String {
        var parts = [store.title(for: e)]
        if e.hasNote { parts.append(e.trimmedNote) }
        parts.append(dayHeading(e.date))
        return parts.joined(separator: " · ")
    }
}

/// All entries of one day (the id is that day's midnight).
private struct DayGroup: Identifiable {
    let id: Date
    let entries: [Entry]
}

/// The big balance at the top, with this month's money in and out.
struct BalanceCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let balance = store.balance
        let month = monthRange(0)
        let t = store.totals(from: month.start, to: month.end)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current Balance")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text(balance > 0.004 ? "Positive" : balance < -0.004 ? "Negative" : "Even")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.money(balance))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.money(balance).opacity(0.15), in: Capsule())
            }
            Text(signedEuro(balance))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Color.money(balance))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Divider()
            HStack {
                MiniStat(icon: "arrow.down.circle.fill", color: .green, title: "In this month", value: signedEuro(t.inc))
                MiniStat(icon: "arrow.up.circle.fill", color: .red, title: "Out this month", value: euro(-t.out))
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(.vertical, 6)
    }
}

private struct MiniStat: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A category button in the grid. `emoji == nil` draws the "New" tile.
struct CategoryTile: View {
    let emoji: String?
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            if let emoji {
                Text(emoji).font(.system(size: 30))
            } else {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(emoji == nil ? Color.accentColor : Color.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
