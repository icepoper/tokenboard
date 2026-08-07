import SwiftUI

/// DeepSeek 弹出面板内容：余额卡片 + 今日/本月用量 + 各模型近 7 天趋势
struct DeepSeekPanel: View {
    let snapshot: DeepSeekSnapshot

    var body: some View {
        Group {
            if let balance = snapshot.balance {
                balanceCard(balance)
                Divider()
            }

            if let usage = snapshot.usage {
                usageSection(usage)
                Divider()
            }

            trendSection
        }
    }

    // MARK: - 余额卡片

    private func balanceCard(_ b: DeepSeekBalance) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("账户余额")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(b.isAvailable ? String(localized: "可用") : String(localized: "不可用"))
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((b.isAvailable ? Color.green : Color.red).opacity(0.15))
                    .foregroundColor(b.isAvailable ? .green : .red)
                    .cornerRadius(4)
            }

            Text("\(Self.currencySymbol(b.currency))\(Self.formatAmount(b.totalBalance))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 12) {
                labeledValue("充值", "\(Self.currencySymbol(b.currency))\(Self.formatAmount(b.toppedUpBalance))")
                labeledValue("赠金", "\(Self.currencySymbol(b.currency))\(Self.formatAmount(b.grantedBalance))")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)

            if !b.isAvailable {
                Text("余额不足，请前往 DeepSeek 平台充值")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 用量摘要

    private func usageSection(_ u: DeepSeekUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用量")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            HStack {
                usageItem("今日 tokens", UsageTrend.humanize(Double(u.todayTokens)))
                Spacer()
                usageItem("本月 tokens", UsageTrend.humanize(Double(u.currentMonthTokens)))
            }

            HStack {
                if let todayCost = u.todayCost {
                    usageItem("今日消费", "\(Self.currencySymbol(u.currency))\(Self.formatAmount(todayCost))")
                }
                Spacer()
                if let monthCost = u.currentMonthCost {
                    usageItem("本月消费", "\(Self.currencySymbol(u.currency))\(Self.formatAmount(monthCost))")
                }
            }

            if let top = u.topModel {
                HStack(spacing: 4) {
                    Text("主要模型")
                    Text(top)
                }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledValue(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
            Text(value)
                .monospacedDigit()
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
    }

    private func usageItem(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }

    // MARK: - 趋势

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("近 7 天各模型 Token 趋势")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            if snapshot.dailyByModel.isEmpty {
                Text("近 7 天暂无调用")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                ForEach(sortedModels, id: \.self) { model in
                    ModelTrendChart(model: model, days: snapshot.dailyByModel[model] ?? [])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sortedModels: [String] {
        snapshot.dailyByModel.keys.sorted {
            let a = snapshot.dailyByModel[$0]?.reduce(0) { $0 + $1.tokens } ?? 0
            let b = snapshot.dailyByModel[$1]?.reduce(0) { $0 + $1.tokens } ?? 0
            return a > b
        }
    }

    // MARK: - 格式化

    static func currencySymbol(_ currency: String) -> String {
        currency.uppercased() == "CNY" ? "¥" : "$"
    }

    static func formatAmount(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
