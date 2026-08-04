import SwiftUI

/// 限额进度条组件
struct QuotaBar: View {
    let title: String
    let usedPercentage: Double     // 0.0 - 1.0
    let remainingCount: Int
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
                Text("剩余 \(Int((1 - usedPercentage) * 100))%")
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

                    // 剩余填充（与千问工作台一致：条 = 剩余比例）
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: max(geo.size.width * (1 - usedPercentage), 4), height: 8)
                }
            }
            .frame(height: 8)

            // 详情行 1: 剩余次数
            HStack {
                Text("剩余 \(remainingCount.formatted()) / 共 \(totalCount.formatted()) 次")
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

    private var resetDetailText: String {
        if resetTimeString == "--:--" {
            return "已重置"
        }
        return "重置于 \(resetTimeString) · 还剩\(resetCountdown)"
    }

    private var remainingColor: Color {
        let remaining = 1 - usedPercentage
        if remaining < 0.1 { return .red }
        if remaining < 0.2 { return .orange }
        return .primary
    }

    private var barColor: Color {
        let remaining = 1 - usedPercentage
        if remaining < 0.1 { return .red }
        if remaining < 0.2 { return .orange }
        return .accentColor
    }
}
