import SwiftUI

/// 限额进度条组件
struct QuotaBar: View {
    let title: String
    let usedPercentage: Double?     // 0.0 - 1.0；nil = 未知
    let remainingCount: Int?        // nil = 未知
    let totalCount: Int
    let resetTimeString: String
    let resetCountdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标题行
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(remainingPercentText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(remainingColor)
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)

                    // 剩余填充（与千问工作台一致：条 = 剩余比例；未知时按满额显示）
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: max(geo.size.width * CGFloat(remainingRatio), 4), height: 8)
                }
            }
            .frame(height: 8)

            // 详情行 1: 剩余次数
            HStack {
                Text("剩余 \(remainingCountText) / 共 \(totalCount.formatted()) 次")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
            }

            // 详情行 2: 重置时间
            HStack {
                Text(resetDetailText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private var remaining: Double? { usedPercentage.map { 1 - $0 } }

    /// 剩余比例（未知时按 1 即满额显示）
    private var remainingRatio: Double { remaining ?? 1 }

    private var remainingPercentText: String {
        guard let r = remaining else { return String(localized: "剩余 --%") }
        return String(localized: "剩余 \(Int(r * 100))%")
    }

    private var remainingCountText: String {
        guard let c = remainingCount else { return "--" }
        return c.formatted()
    }

    private var resetDetailText: String {
        if resetTimeString == "--:--" {
            return String(localized: "已重置")
        }
        return String(localized: "重置时间 \(resetTimeString) · 还剩\(resetCountdown)")
    }

    private var remainingColor: Color {
        guard let r = remaining else { return .primary }
        if r < 0.1 { return .red }
        if r < 0.2 { return .orange }
        return .primary
    }

    private var barColor: Color {
        guard let r = remaining else { return .accentColor }
        if r < 0.1 { return .red }
        if r < 0.2 { return .orange }
        return .accentColor
    }
}
