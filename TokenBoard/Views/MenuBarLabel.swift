import SwiftUI

/// 菜单栏状态栏：胶囊徽章（QW 字母 + 百分比）
struct MenuBarLabel: View {
    @EnvironmentObject var polling: PollingService
    @EnvironmentObject var credentials: CredentialManager

    var body: some View {
        ProgressRing(progress: ringProgress, text: labelText)
    }

    // MARK: - 状态计算

    /// 持续失败（连接异常）时菜单栏显示 "!"，不再假装数据正常
    private var hasError: Bool {
        polling.isFailing || polling.state == .error
    }

    private var ringProgress: Double {
        switch credentials.status {
        case .complete:
            if hasError { return 0 }
            guard let data = polling.planData else { return 0 }
            return max(0, min(data.minRemainingPercentage, 1))
        case .incomplete, .expired:
            return 0
        }
    }

    private var labelText: String {
        switch credentials.status {
        case .incomplete:
            return "?"
        case .expired:
            return "!"
        case .complete:
            if hasError { return "!" }
            guard let data = polling.planData else { return "-- | --" }
            return data.remainingPercentText
        }
    }
}
