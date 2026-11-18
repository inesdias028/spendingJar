import SwiftUI

/// Recurring money in and out, with Add and swipe-to-stop.
struct RecurringView: View {
    @Environment(Store.self) private var store
    @State private var adding = false
    @State private var pendingStop: Recurring?

    var body: some View {
        let items = store.recurring.sorted { $0.next < $1.next }
        let incomes = items.filter { $0.income }
        let costs = items.filter { !$0.income }
        let perMonth = items.reduce(0) { $0 + $1.perMonth }

        List {
            if !incomes.isEmpty {
                Section("Money in") {
                    ForEach(incomes) { r in row(r) }
                }
            }
            if !costs.isEmpty {
                Section("Money out") {
                    ForEach(costs) { r in row(r) }
                }
            }
            Section {
                Button {
                    adding = true
                } label: {
                    Label("Add Recurring", systemImage: "plus.circle.fill")
                }
            } footer: {
                Text(items.isEmpty
                     ? "Add things that happen regularly: your salary, rent, the gym or Netflix. They are added to your balance automatically on each date."
                     : "Together about \(signedEuro(perMonth)) a month. Swipe left to stop one.")
            }
        }
        .navigationTitle("Recurring")
        .sheet(isPresented: $adding) {
            NavigationStack { AddRecurringView() }
        }
        .alert(
            "Stop \u{201C}\(pendingStop?.title ?? "")\u{201D}?",
            isPresented: Binding(get: { pendingStop != nil }, set: { if !$0 { pendingStop = nil } }),
            presenting: pendingStop
        ) { r in
            Button("Stop", role: .destructive) { store.deleteRecurring(r.id) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Entries already added stay in your list.")
        }
    }

    private func row(_ r: Recurring) -> some View {
        HStack(spacing: 12) {
            EmojiBadge(emoji: r.emoji)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.title)
                Text("\(r.freq.freqName) · next \(shortDate(r.next))")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            Text(signedEuro(r.income ? r.amount : -r.amount))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(r.income ? Color.green : Color.primary)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingStop = r
            } label: {
                Label("Stop", systemImage: "stop.circle")
            }
        }
    }
}

struct AddRecurringView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var income = false
    @State private var name = ""
    @State private var amountText = ""
    @State private var freq: Period = .month
    @State private var categoryKey = ""
    @State private var start = Date()
    @State private var error: String?

    var body: some View {
        let cats = store.categories(income: income)
        Form {
            Section {
                Picker("Type", selection: $income) {
                    Text("Spending").tag(false)
                    Text("Income").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: income) { _, _ in categoryKey = "" }
            }

            Section {
                TextField(income ? "Name, like Salary" : "Name, like Rent or Netflix", text: $name)
                    .textInputAutocapitalization(.sentences)
                HStack {
                    Text(income ? "+ €" : "− €").foregroundStyle(income ? Color.green : Color.secondary)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .onChange(of: amountText) { _, _ in error = nil }
                }
            } footer: {
                if let error { Text(error).foregroundStyle(Color.red) }
            }

            Section {
                Picker("Repeats", selection: $freq) {
                    ForEach(Period.allCases) { p in Text(p.freqName).tag(p) }
                }
                .pickerStyle(.segmented)
                Picker(income ? "Source" : "Category", selection: $categoryKey) {
                    ForEach(cats) { c in
                        Text("\(c.emoji) \(c.label)").tag(c.key)
                    }
                }
                DatePicker("First date", selection: $start, displayedComponents: .date)
            } footer: {
                Text(dayStart(start) > dayStart(Date())
                     ? "It will be added for the first time on \(shortDate(start))."
                     : "Everything from \(shortDate(start)) until today is added straight away.")
            }
        }
        .navigationTitle("New Recurring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { save(cats) }
            }
        }
        .onAppear { if categoryKey.isEmpty { categoryKey = cats.first?.key ?? "" } }
        .onChange(of: categoryKey) { _, key in
            if key.isEmpty { categoryKey = cats.first?.key ?? "" }
        }
    }

    private func save(_ cats: [Category]) {
        guard let amount = parseAmount(amountText) else {
            error = "Enter an amount, like 9,99."
            return
        }
        let category = cats.first { $0.key == categoryKey }
            ?? cats.first
            ?? (income ? defaultIncomeCategories.last! : defaultCategories.last!)
        store.addRecurring(name: name, amount: amount, category: category, freq: freq, start: start)
        dismiss()
    }
}
