import SwiftUI

/// 最近 7 天用量趋势图（堆叠柱状图，点击查看单日明细）
struct TrendChartView: View {
    let trend: UsageTrend?
    /// 趋势最近一次失败原因（nil = 正常）
    let errorMessage: String?

    /// 选中的天（nil 表示默认选最后一天）
    @State private var selectedIndex: Int?

    /// 柱状图区域高度
    private let chartHeight: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                Text("最近 7 天用量")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let trend {
                    Text("周总量 \(UsageTrend.humanize(trend.weekTotal))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            if let trend, !trend.days.isEmpty {
                chartView(trend)
                detailRow(trend)
                legendRow
            } else if trend == nil, let errorMessage {
                // 拉取失败：展示原因，不再静默装死
                VStack(alignment: .leading, spacing: 4) {
                    Text("趋势加载失败")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    Text("点击刷新重试")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if trend == nil {
                // 首次加载、接口尚未返回：明确是"加载中"而不是"没数据"
                HStack(spacing: 6) {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("趋势加载中...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                Text("暂无用量数据")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            }
        }
    }

    // MARK: - 柱状图

    private func chartView(_ trend: UsageTrend) -> some View {
        let maxTotal = max(trend.days.map(\.totalTokens).max() ?? 0, 1)
        let selected = effectiveSelectedIndex(trend)

        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(trend.days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 3) {
                    barStack(for: day, maxTotal: maxTotal)
                        .frame(height: chartHeight, alignment: .bottom)
                        .opacity(index == selected ? 1 : 0.5)
                    Text(day.dayLabel)
                        .font(.system(size: 8))
                        .foregroundColor(index == selected ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { selectedIndex = index }
                .help("\(day.dayLabel) 总量 \(UsageTrend.humanize(day.totalTokens))")
            }
        }
    }

    /// 单根堆叠柱：自下而上 = 非缓存输入（浅）/ 缓存（中）/ 输出（深）
    private func barStack(for day: UsageDay, maxTotal: Double) -> some View {
        // 柱体最多占 chartHeight - 4，顶部留白
        let scale = (chartHeight - 4) / maxTotal
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            if day.totalTokens <= 0 {
                // 无用量也画一条基线，保持图形可读
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: 2)
            } else {
                segment(height: day.uncachedInputTokens * scale, color: Self.inputColor)
                segment(height: day.cachedTokens * scale, color: Self.cachedColor)
                segment(height: day.outputTokens * scale, color: Self.outputColor)
            }
        }
    }

    /// 单个色段：正值至少 1.5pt，保证可见
    private func segment(height: Double, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(height: height > 0 ? max(CGFloat(height), 1.5) : 0)
    }

    // MARK: - 明细行

    private func detailRow(_ trend: UsageTrend) -> some View {
        let day = trend.days[effectiveSelectedIndex(trend)]
        return HStack(spacing: 10) {
            Text(day.dayLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
            Text("总量 \(UsageTrend.humanize(day.totalTokens))")
            Text("缓存命中 \(Int(day.cacheHitRate * 100))%")
            Text("输出 \(UsageTrend.humanize(day.outputTokens))")
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.secondary)
    }

    // MARK: - 图例

    private var legendRow: some View {
        HStack(spacing: 10) {
            legendItem(color: Self.inputColor, label: "输入")
            legendItem(color: Self.cachedColor, label: "缓存")
            legendItem(color: Self.outputColor, label: "输出")
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 颜色

    private static let outputColor = Color.accentColor
    private static let cachedColor = Color.accentColor.opacity(0.55)
    private static let inputColor = Color.accentColor.opacity(0.25)

    // MARK: - 辅助

    private func effectiveSelectedIndex(_ trend: UsageTrend) -> Int {
        let fallback = trend.days.count - 1
        guard let idx = selectedIndex else { return fallback }
        return min(max(idx, 0), fallback)
    }
}
