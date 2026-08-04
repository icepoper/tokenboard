import SwiftUI
import AppKit

/// 胶囊徽章（QW 字母 + 百分比，单 Text 渲染）
struct ProgressRing: View {
    /// 直接持有设置单例（@ObservedObject 在 NSStatusItem 中可靠触发更新）
    @ObservedObject private var settings = AppSettings.shared

    /// 剩余比例 0.0 - 1.0
    let progress: Double

    /// 百分比文字（nil 时显示 "--"）
    let text: String

    init(progress: Double, text: String? = nil) {
        self.progress = progress
        self.text = text ?? "\(Int(progress * 100))%"
    }

    var body: some View {
        // 单个 Text 完整渲染；文字固定白色；无边框
        Text("QW \(text)")
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
