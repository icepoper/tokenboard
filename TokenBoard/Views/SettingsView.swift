import SwiftUI
import ServiceManagement

/// 设置窗口
struct SettingsView: View {
    @EnvironmentObject var polling: PollingService
    @EnvironmentObject var credentials: CredentialManager
    @EnvironmentObject var settings: AppSettings

    @State private var cookieInput = ""
    @State private var secTokenInput = ""
    @State private var showSaved = false
    @State private var launchAtLogin = false
    @State private var notificationStatus = ""

    private let intervalOptions = [15, 30, 60, 120, 300]

    private var notificationStatusText: String {
        switch notificationStatus {
        case "未请求": return String(localized: "未请求（点重新请求授权）")
        case "已拒绝": return String(localized: "已拒绝（需在系统设置开启）")
        case "已授权", "临时授权": return String(localized: "已授权 ✓")
        case "会话授权": return String(localized: "会话授权")
        case "未知": return String(localized: "未知")
        default: return notificationStatus.isEmpty ? String(localized: "未请求") : notificationStatus
        }
    }

    private var notificationStatusColor: Color {
        switch notificationStatus {
        case "已授权", "临时授权": return .green
        case "已拒绝": return .red
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置")
                .font(.system(size: 16, weight: .bold))

            // MARK: 凭证区
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("凭证配置")
                        .font(.system(size: 13, weight: .semibold))

                    Text("从浏览器 DevTools 复制 Cookie 和 sec_token")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cookie")
                            .font(.system(size: 11, weight: .medium))
                        TextEditor(text: $cookieInput)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(height: 80)
                            .border(Color.secondary.opacity(0.3), width: 1)
                            .cornerRadius(4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("sec_token")
                            .font(.system(size: 11, weight: .medium))
                        TextField("粘贴 sec_token", text: $secTokenInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                    }

                    HStack {
                        Button("保存") {
                            saveCredentials()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(cookieInput.isEmpty || secTokenInput.isEmpty)

                        Button("清除") {
                            clearCredentials()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        if showSaved {
                            Text("已保存")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }

                        statusBadge
                    }
                }
                .padding(8)
            }

            // MARK: 轮询设置
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("轮询设置")
                        .font(.system(size: 13, weight: .semibold))

                    HStack {
                        Text("刷新间隔")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { polling.pollingInterval },
                            set: { polling.pollingInterval = $0 }
                        )) {
                            ForEach(intervalOptions, id: \.self) { interval in
                                Text("\(interval) 秒").tag(interval)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }

                    Toggle("开机自启", isOn: $launchAtLogin)
                        .font(.system(size: 12))
                        .onChange(of: launchAtLogin) { newValue in
                            setLaunchAtLogin(newValue)
                        }
                }
                .padding(8)
            }

            // MARK: 语言
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("语言")
                        .font(.system(size: 13, weight: .semibold))

                    HStack {
                        Text("界面语言")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $settings.language) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                        .onChange(of: settings.language) { newValue in
                            handleLanguageChange(newValue)
                        }
                    }

                    Text("切换语言后需重启应用生效")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            // MARK: 胶囊外观
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("胶囊外观")
                        .font(.system(size: 13, weight: .semibold))

                    HStack {
                        Text("背景颜色")
                            .font(.system(size: 12))
                        Spacer()
                        ColorPicker("", selection: $settings.capsuleBackgroundColor, supportsOpacity: false)
                            .labelsHidden()
                    }

                    HStack {
                        Text("默认深墨蓝，显眼且随状态色描边")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("恢复默认") {
                            settings.resetCapsuleColor()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(8)
            }

            // MARK: 通知权限
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("通知权限")
                        .font(.system(size: 13, weight: .semibold))

                    HStack {
                        Text("额度预警状态")
                            .font(.system(size: 12))
                        Spacer()
                        Text(notificationStatusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(notificationStatusColor)

                        Button("重新请求") {
                            Task {
                                await NotificationHelper.shared.requestPermission()
                                notificationStatus = NotificationHelper.shared.statusDescription
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(notificationStatus == "已授权" || notificationStatus == "临时授权")

#if DEBUG
                        Button("发送测试通知") {
                            NotificationHelper.shared.sendTestNotification()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(notificationStatus != "已授权" && notificationStatus != "临时授权")
#endif
                    }
                }
                .padding(8)
            }

            // MARK: 关于
            GroupBox {
                HStack {
                    Text("TokenBoard v\(appVersion)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("macOS 菜单栏千问 Token Plan 监控")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            HStack {
                Spacer()
                Text("按 ⌘Q 退出应用")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            // LSUIElement 应用需要激活才能让键盘焦点进入输入框
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
            if #available(macOS 13.0, *) {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
            // 刷新通知权限状态
            notificationStatus = NotificationHelper.shared.statusDescription
            Task {
                await NotificationHelper.shared.refreshStatus()
                notificationStatus = NotificationHelper.shared.statusDescription
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let b = info?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    // MARK: - 状态标记

    private var statusBadge: some View {
        Group {
            switch credentials.status {
            case .complete:
                Text("已配置")
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            case .expired:
                Text("已过期")
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            case .incomplete:
                Text("未配置")
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - 操作

    private func saveCredentials() {
        credentials.save(cookie: cookieInput, secToken: secTokenInput)
        cookieInput = ""
        secTokenInput = ""
        withAnimation { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSaved = false }
        }
        polling.restartIfNeeded()
    }

    private func clearCredentials() {
        credentials.clear()
        polling.stop()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = !enabled
            }
        }
    }

    // MARK: - 语言切换

    /// 语言变化处理：若所选语言不是当前生效语言，提示重启
    private func handleLanguageChange(_ newLanguage: AppLanguage) {
        // 所选语言已是当前生效语言时无需重启（如系统中文下选中文）
        if let code = newLanguage.appleLanguagesCode,
           code == Bundle.main.preferredLocalizations.first {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: "切换语言需要重启应用")
        alert.informativeText = String(localized: "重启后语言设置立即生效。")
        alert.addButton(withTitle: String(localized: "立即重启"))
        alert.addButton(withTitle: String(localized: "稍后"))
        if alert.runModal() == .alertFirstButtonReturn {
            relaunchApp()
        }
    }

    /// 重新启动应用：用 `open -n` 强制拉起新实例（旧实例仍在运行），稍后退出当前实例
    private func relaunchApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        try? process.run()
        // 留出新实例启动时间，再退出当前实例，避免出现空窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApp.terminate(nil)
        }
    }
}
