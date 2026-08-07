import SwiftUI
import AppKit

/// 胶囊徽章（服务商前缀 + 状态文字，单 Text 渲染）
struct ProgressRing: View {
    /// 直接持有设置单例（@ObservedObject 在 NSStatusItem 中可靠触发更新）
    @ObservedObject private var settings = AppSettings.shared

    /// 剩余比例 0.0 - 1.0
    let progress: Double

    /// 状态文字（nil 时显示 "--"）
    let text: String

    /// 服务商前缀（QW / DS）
    let prefix: String

    init(progress: Double, text: String? = nil, prefix: String = "QW") {
        self.progress = progress
        self.text = text ?? "\(Int(progress * 100))%"
        self.prefix = prefix
    }

    var body: some View {
        // 单个 Text 完整渲染；文字固定白色；无边框
        Text("\(prefix) \(text)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(settings.capsuleBackgroundColor)
            )
    }
}
