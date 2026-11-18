import Foundation

// The same data the web app stores in Firebase, so both apps share one account.
//   users/{uid}               -> { startBalance, categories, recurring, updatedAt }
//   users/{uid}/expenses/{id} -> { amount, income?, category, emoji, label, date, note? }

enum Period: String, CaseIterable, Identifiable {
    case week, month, year
    var id: String { rawValue }
    var freqName: String {
        switch self {
        case .week: return "Weekly"
        case .month: return "Monthly"
        case .year: return "Yearly"
        }
    }
}

struct Category: Identifiable, Hashable {
    var key: String
    var label: String
    var emoji: String
    /// true = a kind of money coming in (salary, gift…), false = spending.
    var income: Bool = false

    var id: String { key }

    var dict: [String: Any] {
        var d: [String: Any] = ["key": key, "label": label, "emoji": emoji]
        if income { d["income"] = true }
        return d
    }
}

extension Category {
    init?(_ d: [String: Any]) {
        guard let key = d["key"] as? String, let label = d["label"] as? String else { return nil }
        self.init(key: key, label: label, emoji: d["emoji"] as? String ?? "🏷️", income: d["income"] as? Bool ?? false)
    }
}

/// One movement of money: spending (out) or income (in).
struct Entry: Identifiable, Hashable {
    var id: String
    /// Always positive. `income` says which way it goes.
    var amount: Double
    var income: Bool
    var category: String
    var emoji: String?
    var label: String?
    var date: Date
    var note: String?

    /// + for income, − for spending.
    var signed: Double { income ? amount : -amount }
    /// Added automatically by a recurring item ('r_<series>_<date>').
    var isRecurring: Bool { id.hasPrefix("r_") }
    var trimmedNote: String { (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasNote: Bool { !trimmedNote.isEmpty }

    /// What is written to Firebase (the id is the document name).
    var dict: [String: Any] {
        var d: [String: Any] = [
            "amount": amount,
            "category": category,
            "date": isoString(date),
        ]
        if income { d["income"] = true }
        if let emoji { d["emoji"] = emoji }
        if let label { d["label"] = label }
        if hasNote { d["note"] = trimmedNote }
        return d
    }
}

extension Entry {
    init?(id: String, _ d: [String: Any]) {
        guard let amount = number(d["amount"]),
              let dateText = d["date"] as? String,
              let date = parseISO(dateText) else { return nil }
        self.init(
            id: id,
            amount: amount,
            income: d["income"] as? Bool ?? false,
            category: d["category"] as? String ?? "other",
            emoji: d["emoji"] as? String,
            label: d["label"] as? String,
            date: date,
            note: d["note"] as? String
        )
    }
}

/// Money in or out that repeats every week, month or year.
struct Recurring: Identifiable, Hashable {
    var id: String
    var name: String
    var amount: Double
    var income: Bool
    var category: String
    var emoji: String
    var label: String
    var freq: Period
    /// Day of the month it started on, so "31st" stays the last day in short months.
    var anchorDay: Int
    /// The next date it will be added.
    var next: Date

    var title: String { name.isEmpty ? label : name }

    /// Roughly what it adds (+) or takes (−) each month.
    var perMonth: Double {
        let sign = income ? amount : -amount
        switch freq {
        case .week: return sign * 52.0 / 12.0
        case .month: return sign
        case .year: return sign / 12.0
        }
    }

    /// The date after `from` for this frequency.
    func after(_ from: Date) -> Date {
        let c = cal.dateComponents([.year, .month], from: from)
        switch freq {
        case .week: return cal.date(byAdding: .day, value: 7, to: from) ?? from
        case .month: return clampDay(year: c.year ?? 2000, month: (c.month ?? 1) + 1, day: anchorDay)
        case .year: return clampDay(year: (c.year ?? 2000) + 1, month: c.month ?? 1, day: anchorDay)
        }
    }

    var dict: [String: Any] {
        var d: [String: Any] = [
            "id": id, "name": name, "amount": amount, "category": category, "emoji": emoji,
            "label": label, "freq": freq.rawValue, "anchorDay": anchorDay, "next": ymd(next),
        ]
        if income { d["income"] = true }
        return d
    }
}

extension Recurring {
    init?(_ d: [String: Any]) {
        guard let id = d["id"] as? String, let amount = number(d["amount"]),
              let nextText = d["next"] as? String, let next = parseYMD(nextText) else { return nil }
        self.init(
            id: id,
            name: d["name"] as? String ?? "",
            amount: amount,
            income: d["income"] as? Bool ?? false,
            category: d["category"] as? String ?? "other",
            emoji: d["emoji"] as? String ?? "🏷️",
            label: d["label"] as? String ?? "Other",
            freq: Period(rawValue: d["freq"] as? String ?? "") ?? .month,
            anchorDay: Int(number(d["anchorDay"]) ?? 1),
            next: next
        )
    }
}

let defaultCategories: [Category] = [
    Category(key: "food", label: "Food", emoji: "🍔"),
    Category(key: "coffee", label: "Coffee", emoji: "☕"),
    Category(key: "transport", label: "Transport", emoji: "🚌"),
    Category(key: "shopping", label: "Shopping", emoji: "🛍️"),
    Category(key: "fun", label: "Fun", emoji: "🎉"),
    Category(key: "other", label: "Other", emoji: "📦"),
]

let defaultIncomeCategories: [Category] = [
    Category(key: "salary", label: "Salary", emoji: "💼", income: true),
    Category(key: "gift_in", label: "Gift", emoji: "🎁", income: true),
    Category(key: "refund", label: "Refund", emoji: "↩️", income: true),
    Category(key: "sold", label: "Sold", emoji: "🏷️", income: true),
    Category(key: "income_other", label: "Other", emoji: "💰", income: true),
]

let suggestedEmojis = ["🏋️", "🐶", "💊", "🎁", "✈️", "🏠", "📚", "🍺", "💇", "🎮", "🚗", "👶"]
let suggestedIncomeEmojis = ["💼", "💶", "🏦", "📈", "🧾", "🎓", "🤝", "🏆"]

// MARK: - Dates

/// Gregorian calendar with weeks starting on Monday, in the phone's time zone.
let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.firstWeekday = 2
    c.timeZone = .current
    return c
}()

let english = Locale(identifier: "en_US")

func dayStart(_ d: Date) -> Date { cal.startOfDay(for: d) }

func monthStart(_ d: Date) -> Date {
    cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? dayStart(d)
}

func clampDay(year: Int, month: Int, day: Int) -> Date {
    let first = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    let last = cal.range(of: .day, in: .month, for: first)?.count ?? 28
    return cal.date(byAdding: .day, value: min(day, last) - 1, to: first) ?? first
}

/// One calendar month: [start, end), plus a label like "November 2026".
struct MonthRange {
    let start: Date
    let end: Date
    var label: String {
        let f = DateFormatter()
        f.locale = english
        f.calendar = cal
        f.dateFormat = "LLLL yyyy"
        return f.string(from: start)
    }
    var shortMonth: String {
        let f = DateFormatter()
        f.locale = english
        f.calendar = cal
        f.dateFormat = "MMM"
        return f.string(from: start)
    }
    var dayCount: Int { cal.range(of: .day, in: .month, for: start)?.count ?? 30 }
}

/// offset 0 = this month, -1 = last month, …
func monthRange(_ offset: Int) -> MonthRange {
    let start = cal.date(byAdding: .month, value: offset, to: monthStart(Date())) ?? monthStart(Date())
    let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
    return MonthRange(start: start, end: end)
}

/// "Today", "Yesterday", "Monday", or "Thursday, 6 November" — like iOS lists.
func dayHeading(_ d: Date) -> String {
    let today = dayStart(Date())
    let diff = cal.dateComponents([.day], from: dayStart(d), to: today).day ?? 0
    if diff == 0 { return "Today" }
    if diff == 1 { return "Yesterday" }
    let f = DateFormatter()
    f.locale = english
    f.calendar = cal
    if diff > 1 && diff < 7 {
        f.dateFormat = "EEEE"
    } else if cal.component(.year, from: d) == cal.component(.year, from: today) {
        f.dateFormat = "EEEE, d MMMM"
    } else {
        f.dateFormat = "EEEE, d MMMM yyyy"
    }
    return f.string(from: d)
}

func hhmm(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = english
    f.dateFormat = "HH:mm"
    return f.string(from: d)
}

func shortDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = english
    f.calendar = cal
    f.dateFormat = "d MMM yyyy"
    return f.string(from: d)
}

/// "2026-11-13" (local day), used for a recurring item's next date.
func ymd(_ d: Date) -> String {
    let c = cal.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
}

/// "20261113", used in the ids of recurring entries.
func ymdCompact(_ d: Date) -> String { ymd(d).replacingOccurrences(of: "-", with: "") }

func parseYMD(_ s: String) -> Date? {
    let parts = s.prefix(10).split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}

/// The web app writes dates like "2026-11-16T12:05:00.000Z" (sometimes with 6 decimals).
func parseISO(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    guard let dot = s.firstIndex(of: ".") else { return f.date(from: s) }
    let after = s[s.index(after: dot)...]
    let digits = after.prefix(while: { $0.isNumber })
    let rest = after.dropFirst(digits.count)
    guard let base = f.date(from: String(s[..<dot]) + rest) else { return nil }
    return base.addingTimeInterval(Double("0." + digits) ?? 0)
}

func isoString(_ d: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.string(from: d)
}

// MARK: - Money

/// Firestore gives numbers as NSNumber (whole or decimal).
func number(_ any: Any?) -> Double? { (any as? NSNumber)?.doubleValue }

/// €1.234,50 — with a real minus sign (−) for negatives.
func euro(_ n: Double) -> String {
    let negative = n < -0.004
    let cents = Int((abs(n) * 100).rounded())
    let whole = String(cents / 100)
    var grouped = ""
    for (i, ch) in whole.reversed().enumerated() {
        if i > 0 && i % 3 == 0 { grouped.append(".") }
        grouped.append(ch)
    }
    return "\(negative ? "−" : "")€\(String(grouped.reversed())),\(String(format: "%02d", cents % 100))"
}

/// +€12,00 or −€4,50 (no sign for zero).
func signedEuro(_ n: Double) -> String { n > 0.004 ? "+" + euro(n) : euro(n) }

/// Accepts "4,50" and "4.50". Returns nil for empty, invalid or zero.
func parseAmount(_ text: String) -> Double? {
    let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    guard let n = Double(t), n > 0 else { return nil }
    return (n * 100).rounded() / 100
}

/// "350" or "12,50" for showing an amount in a text field.
func plainAmount(_ v: Double) -> String {
    if v == 0 { return "" }
    let t = String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
    return t.hasSuffix(",00") ? String(t.dropLast(3)) : t
}
