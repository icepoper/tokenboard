import SwiftUI
import AppKit

/// 弹出面板主视图：展示活动服务商的监控数据
struct PopoverView: View {
    @EnvironmentObject var providers: ProviderManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            providerSwitcher

            if provider.isFailing || provider.state == .error {
                errorBanner
            }

            Divider()

            providerContent

            Divider()

            actionButtons
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: - 活动服务商

    private var provider: any Provider { providers.activeProvider }

    // MARK: - 标题

    private var headerSection: some View {
        HStack {
            Text(headerTitle)
                .font(.system(size: 14, weight: .bold))
            Spacer()
            if let lastUpdated = provider.lastUpdated {
                Text("更新于 \(Self.timeFormatter.string(from: lastUpdated))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var headerTitle: String {
        switch provider.id {
        case .qianwen: return "Token Plan"
        case .deepseek: return "DeepSeek"
        }
    }


    // MARK: - 服务商切换

    private var providerSwitcher: some View {
        HStack {
            Spacer()
            ProviderSwitcher()
            Spacer()
        }
    }

    // MARK: - 内容区（按活动服务商快照分发）

    @ViewBuilder
    private var providerContent: some View {
        switch provider.credentialStatus {
        case .incomplete, .expired:
            credentialWarning
        case .complete:
            if let snapshot = provider.snapshot {
                switch snapshot {
                case .qianwen(let s):
                    qianwenContent(s)
                case .deepseek(let s):
                    DeepSeekPanel(snapshot: s)
                }
            } else {
                loadingSection
            }
        }
    }

    private func qianwenContent(_ s: QianwenSnapshot) -> some View {
        Group {
            subscriptionSection(s.planData.subscription)
            Divider()
            quotaSection(s.planData)
            Divider()
            addonSection(s.planData.resetCards)
            Divider()
            trendSection(trend: s.trend, errorMessage: s.trendError)
        }
    }

    // MARK: - 更新失败横幅

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// 持续失败时展示：明确告知用户当前是旧数据，而不是静默装死
    private var errorBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Text("数据更新失败")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
            }
            if let msg = provider.lastError {
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Text("当前显示的是旧数据，请点击刷新重试")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(6)
    }

    // MARK: - 凭证警告

    private var credentialWarning: some View {
        VStack(spacing: 8) {
            Image(systemName: provider.credentialStatus == .expired
                  ? "exclamationmark.triangle.fill"
                  : "key.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            Text(provider.credentialStatus == .expired
                 ? "登录已过期"
                 : "尚未配置凭证")
                .font(.system(size: 13, weight: .medium))
            Text(credentialHint)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("打开设置") {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    /// 凭证提示文案（按服务商区分）
    private var credentialHint: String {
        switch provider.id {
        case .qianwen: return String(localized: "请在设置中粘贴 Cookie 和 sec_token")
        case .deepseek: return String(localized: "请在设置中粘贴 DeepSeek userToken")
        }
    }

    // MARK: - 套餐信息

    private func subscriptionSection(_ sub: SubscriptionInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(sub.specDisplayName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(sub.statusDisplayName)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sub.status == "VALID" ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .foregroundColor(sub.status == "VALID" ? .green : .red)
                        .cornerRadius(4)
                }
                Text("剩余 \(sub.remainingDays) 天 · 到期 \(sub.endDateString)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if sub.autoRenewFlag {
                Text("自动续费")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 限额

    private func quotaSection(_ data: PlanData) -> some View {
        VStack(spacing: 14) {
            QuotaBar(
                title: String(localized: "5h 限额"),
                usedPercentage: data.usage.per5HourPercentage,
                remainingCount: data.fiveHourRemainingCount,
                totalCount: Int(data.quota.fiveHour),
                resetTimeString: data.fiveHourResetTimeString,
                resetCountdown: data.fiveHourResetCountdown
            )
            QuotaBar(
                title: String(localized: "7d 限额"),
                usedPercentage: data.usage.per1WeekPercentage,
                remainingCount: data.weeklyRemainingCount,
                totalCount: Int(data.quota.weekly),
                resetTimeString: data.weeklyResetTimeString,
                resetCountdown: data.weeklyResetCountdown
            )
        }
    }

    // MARK: - 用量趋势

    private func trendSection(trend: UsageTrend?, errorMessage: String?) -> some View {
        TrendChartView(trend: trend, errorMessage: errorMessage)
    }

    // MARK: - 加油包

    private func addonSection(_ cards: [ResetCard]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("加油包")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            if cards.isEmpty {
                Text("暂无加油包")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                ForEach(cards) { card in
                    HStack {
                        Text("加油包")
                            .font(.system(size: 11))
                        Spacer()
                        Text("\(Int(card.quota).formatted()) 次")
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
            }
        }
    }

    // MARK: - 加载中

    private var loadingSection: some View {
        HStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("加载中...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - 打开设置窗口

    private func openSettings() {
        // 打开独立设置窗口（WindowGroup id=settings）
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task { await provider.refresh() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: provider.state == .refreshing
                          ? "arrow.triangle.2.circlepath"
                          : "arrow.clockwise")
                    Text(provider.state == .refreshing ? String(localized: "刷新中") : String(localized: "刷新"))
                }
                .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .disabled(provider.state == .refreshing)

            Spacer()

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)

            Button {
                if let url = URL(string: consoleURL) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help(consoleURL)

            Divider()
                .frame(height: 12)

            // 退出应用
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            .help("退出 TokenBoard")
        }
    }

    /// 服务商控制台地址（供外链按钮使用）
    private var consoleURL: String {
        switch provider.id {
        case .qianwen:
            return "https://platform.qianwenai.com/home/billing/subscription/token-plan-individual"
        case .deepseek:
            return "https://platform.deepseek.com/usage"
        }
    }
}
