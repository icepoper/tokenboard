import SwiftUI

/// 菜单栏状态栏：胶囊徽章（服务商字母 + 状态文字）
struct MenuBarLabel: View {
    @EnvironmentObject var providers: ProviderManager

    var body: some View {
        ProgressRing(progress: ringProgress, text: labelText, prefix: prefix)
    }

    // MARK: - 状态计算

    private var provider: any Provider { providers.activeProvider }

    /// 胶囊前缀（QW / DS）
    private var prefix: String {
        switch provider.id {
        case .qianwen: return "QW"
        case .deepseek: return "DS"
        }
    }

    /// 持续失败（连接异常）时菜单栏显示 "!"，不再假装数据正常
    private var hasError: Bool {
        provider.isFailing || provider.state == .error
    }

    private var ringProgress: Double {
        switch provider.credentialStatus {
        case .complete:
            if hasError { return 0 }
            guard let snapshot = provider.snapshot else { return 0 }
            switch snapshot {
            case .qianwen(let s):
                return max(0, min(s.planData.minRemainingPercentage, 1))
            case .deepseek(let s):
                // 有余额且可用 = 满环；无余额 / 不可用 / 未加载 = 空环
                guard let balance = s.balance else { return 0 }
                return balance.isAvailable ? 1 : 0
            }
        case .incomplete, .expired:
            return 0
        }
    }

    private var labelText: String {
        switch provider.credentialStatus {
        case .incomplete:
            return "?"
        case .expired:
            return "!"
        case .complete:
            if hasError { return "!" }
            guard let snapshot = provider.snapshot else { return "--" }
            switch snapshot {
            case .qianwen(let s):
                return s.planData.remainingPercentText
            case .deepseek(let s):
                guard let balance = s.balance else { return "--" }
                let symbol = DeepSeekPanel.currencySymbol(balance.currency)
                return "\(symbol)\(String(format: "%.2f", balance.totalBalance))"
            }
        }
    }
}
