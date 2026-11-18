import SwiftUI
import Charts

struct StatsView: View {
    @Environment(Store.self) private var store
    /// 0 = this month, -1 = last month, …
    @State private var offset = 0

    var body: some View {
        let r = monthRange(offset)
        let t = store.totals(from: r.start, to: r.end)
        let net = t.inc - t.out
        let now = Date()
        let startBalance = store.balance(before: r.start)
        let endBalance = store.balance(before: r.end > now ? now.addingTimeInterval(1) : r.end)
        let groups = categoryGroups(from: r.start, to: r.end)

        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section {
                        HStack {
                            Button {
                                offset -= 1
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            Spacer()
                            Text(r.label).font(.headline)
                            Spacer()
                            Button {
                                offset += 1
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(offset >= 0)
                        }
                        .buttonStyle(.borderless)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(net >= 0 ? "You saved" : "You spent more than you earned")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                            Text(signedEuro(net))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.money(net))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            SplitBar(inc: t.inc, out: t.out)
                            HStack(spacing: 14) {
                                Label(signedEuro(t.inc), systemImage: "circle.fill")
                                    .foregroundStyle(Color.green)
                                Label(euro(-t.out), systemImage: "circle.fill")
                                    .foregroundStyle(Color.red)
                            }
                            .font(.footnote)
                            .labelStyle(DotLabelStyle())
                        }
                        .padding(.vertical, 4)
                    }
                    .id("top")

                    Section("Day by day") {
                        DayChart(start: r.start, days: r.dayCount, store: store)
                            .frame(height: 180)
                            .padding(.vertical, 6)
                    }

                    Section("Balance") {
                        LabeledContent("On 1 \(r.shortMonth)") {
                            Text(signedEuro(startBalance)).foregroundStyle(Color.money(startBalance))
                        }
                        LabeledContent(offset == 0 ? "Now" : "End of month") {
                            Text(signedEuro(endBalance)).foregroundStyle(Color.money(endBalance))
                        }
                    }

                    if !groups.spend.isEmpty {
                        Section("Spending by category") {
                            ForEach(groups.spend) { g in
                                GroupRow(group: g, total: t.out, top: groups.spend.first?.total ?? 1, color: .red)
                            }
                        }
                    }
                    if !groups.earn.isEmpty {
                        Section("Income by source") {
                            ForEach(groups.earn) { g in
                                GroupRow(group: g, total: t.inc, top: groups.earn.first?.total ?? 1, color: .green)
                            }
                        }
                    }

                    Section {
                        ForEach(monthsWithActivity(), id: \.self) { i in
                            let m = monthRange(-i)
                            let mt = store.totals(from: m.start, to: m.end)
                            Button {
                                offset = -i
                                withAnimation { proxy.scrollTo("top", anchor: .top) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(m.label)
                                            .fontWeight(-i == offset ? .semibold : .regular)
                                            .foregroundStyle(Color.primary)
                                        Text("\(signedEuro(mt.inc)) in · \(euro(-mt.out)) out")
                                            .font(.caption)
                                            .foregroundStyle(Color.secondary)
                                    }
                                    Spacer()
                                    Text(signedEuro(mt.inc - mt.out))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.money(mt.inc - mt.out))
                                }
                            }
                        }
                    } header: {
                        Text("Last 12 months")
                    } footer: {
                        Text("Tap a month to see it in detail.")
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Stats")
            }
        }
    }

    /// Months (0 = this one) in the last year that have entries; this month always shows.
    private func monthsWithActivity() -> [Int] {
        (0..<12).filter { i in
            let m = monthRange(-i)
            return i == 0 || !store.entries(from: m.start, to: m.end).isEmpty
        }
    }

    private func categoryGroups(from: Date, to: Date) -> (spend: [CategoryTotal], earn: [CategoryTotal]) {
        var spend: [String: CategoryTotal] = [:]
        var earn: [String: CategoryTotal] = [:]
        for e in store.entries(from: from, to: to) {
            let c = store.category(for: e)
            if e.income {
                earn[e.category, default: CategoryTotal(id: e.category, emoji: c.emoji, label: c.label)].add(e.amount)
            } else {
                spend[e.category, default: CategoryTotal(id: e.category, emoji: c.emoji, label: c.label)].add(e.amount)
            }
        }
        return (spend.values.sorted { $0.total > $1.total }, earn.values.sorted { $0.total > $1.total })
    }
}

struct CategoryTotal: Identifiable {
    let id: String
    let emoji: String
    let label: String
    var total = 0.0
    var count = 0

    mutating func add(_ amount: Double) {
        total += amount
        count += 1
    }
}

private struct GroupRow: View {
    let group: CategoryTotal
    let total: Double
    let top: Double
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            EmojiBadge(emoji: group.emoji)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(group.label)
                    Text("\(group.count)×")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Text(euro(group.total)).fontWeight(.semibold).monospacedDigit()
                }
                HStack(spacing: 8) {
                    ShareBar(fraction: top > 0 ? group.total / top : 0, color: color)
                    Text("\(total > 0 ? Int((group.total / total * 100).rounded()) : 0)%")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// One bar split into green (in) and red (out).
private struct SplitBar: View {
    let inc: Double
    let out: Double

    var body: some View {
        GeometryReader { geo in
            let total = inc + out
            HStack(spacing: total > 0 && inc > 0 && out > 0 ? 2 : 0) {
                if total == 0 {
                    Capsule().fill(Color(.systemFill))
                } else {
                    if inc > 0 { Capsule().fill(Color.green).frame(width: geo.size.width * inc / total) }
                    if out > 0 { Capsule().fill(Color.red) }
                }
            }
        }
        .frame(height: 10)
    }
}

private struct DotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.font(.system(size: 7))
            configuration.title.foregroundStyle(Color.primary)
        }
    }
}

/// Money in above the line, money out below, one bar per day.
private struct DayChart: View {
    let start: Date
    let days: Int
    let store: Store

    struct Point: Identifiable {
        let id: String
        let day: Double
        let value: Double
        let kind: String
    }

    var body: some View {
        let points = makePoints()
        if points.allSatisfy({ $0.value == 0 }) {
            ContentUnavailableView("Nothing this month", systemImage: "chart.bar")
        } else {
            Chart(points) { p in
                BarMark(x: .value("Day", p.day), y: .value("Amount", p.value))
                    .foregroundStyle(by: .value("Kind", p.kind))
                    .cornerRadius(3)
            }
            .chartForegroundStyleScale(["In": Color.green, "Out": Color.red])
            .chartLegend(.hidden)
            .chartXScale(domain: 0.5...(Double(days) + 0.5))
            .chartXAxis {
                AxisMarks(values: [1.0, 5, 10, 15, 20, 25, 30].filter { $0 <= Double(days) })
            }
        }
    }

    private func makePoints() -> [Point] {
        var points: [Point] = []
        for i in 0..<days {
            let from = cal.date(byAdding: .day, value: i, to: start) ?? start
            let to = cal.date(byAdding: .day, value: 1, to: from) ?? from
            let t = store.totals(from: from, to: to)
            points.append(Point(id: "in\(i)", day: Double(i + 1), value: t.inc, kind: "In"))
            points.append(Point(id: "out\(i)", day: Double(i + 1), value: -t.out, kind: "Out"))
        }
        return points
    }
}
