import SwiftUI
import AppKit

/// 弹出面板主视图
struct PopoverView: View {
    @EnvironmentObject var polling: PollingService
    @EnvironmentObject var credentials: CredentialManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            if polling.isFailing || polling.state == .error {
                errorBanner
            }

            Divider()

            if credentials.status == .incomplete || credentials.status == .expired {
                credentialWarning
            } else if let data = polling.planData {
                subscriptionSection(data.subscription)
                Divider()
                quotaSection(data)
                Divider()
                trendSection
                Divider()
                addonSection(data.resetCards)
            } else {
                loadingSection
            }

            Divider()

            actionButtons
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: - 标题

    private var headerSection: some View {
        HStack {
            Text("Token Plan")
                .font(.system(size: 14, weight: .bold))
            Spacer()
            if let lastUpdated = polling.lastUpdated {
                Text("更新于 \(Self.timeFormatter.string(from: lastUpdated))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
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
            if let msg = polling.lastError {
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
            Image(systemName: credentials.status == .expired
                  ? "exclamationmark.triangle.fill"
                  : "key.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            Text(credentials.status == .expired
                 ? "登录已过期"
                 : "尚未配置凭证")
                .font(.system(size: 13, weight: .medium))
            Text("请在设置中粘贴 Cookie 和 sec_token")
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
                title: "5h 限额",
                usedPercentage: data.usage.per5HourPercentage,
                remainingCount: data.fiveHourRemainingCount,
                totalCount: Int(data.quota.fiveHour),
                resetTimeString: data.fiveHourResetTimeString,
                resetCountdown: data.fiveHourResetCountdown
            )
            QuotaBar(
                title: "7d 限额",
                usedPercentage: data.usage.per1WeekPercentage,
                remainingCount: data.weeklyRemainingCount,
                totalCount: Int(data.quota.weekly),
                resetTimeString: data.weeklyResetTimeString,
                resetCountdown: data.weeklyResetCountdown
            )
        }
    }

    // MARK: - 用量趋势

    private var trendSection: some View {
        TrendChartView(trend: polling.trend)
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
                Task { await polling.refresh() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: polling.state == .refreshing
                          ? "arrow.triangle.2.circlepath"
                          : "arrow.clockwise")
                    Text(polling.state == .refreshing ? "刷新中" : "刷新")
                }
                .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .disabled(polling.state == .refreshing)

            Spacer()

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)

            Button {
                if let url = URL(string: "https://platform.qianwenai.com/home/billing/subscription/token-plan-individual") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("打开千问工作台")

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
}
