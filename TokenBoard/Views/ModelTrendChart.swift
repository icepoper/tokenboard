import SwiftUI

/// 单模型近 7 天 token 柱状图（多模型时每个模型渲染一张）
struct ModelTrendChart: View {
    let model: String
    let days: [DeepSeekDayUsage]

    private let chartHeight: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(model)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 4) {
                    Text("7 天合计")
                    Text(UsageTrend.humanize(Double(totalTokens)))
                        .monospacedDigit()
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(days, id: \.date) { day in
                        VStack(spacing: 3) {
                            bar(day, height: geo.size.height - 12)
                            Text(dayLabel(day.date))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .frame(height: chartHeight)
        }
    }

    private var totalTokens: Int {
        days.reduce(0) { $0 + $1.tokens }
    }

    private func bar(_ day: DeepSeekDayUsage, height: CGFloat) -> some View {
        let maxTokens = max(days.map(\.tokens).max() ?? 1, 1)
        let ratio = maxTokens > 0 ? CGFloat(day.tokens) / CGFloat(maxTokens) : 0
        return RoundedRectangle(cornerRadius: 2)
            .fill(day.tokens > 0 ? Color.accentColor : Color.secondary.opacity(0.15))
            .frame(height: max(height * ratio, 2))
            .frame(maxWidth: .infinity)
    }

    /// yyyy-MM-dd -> MM-dd
    private func dayLabel(_ date: String) -> String {
        String(date.suffix(5))
    }
}
