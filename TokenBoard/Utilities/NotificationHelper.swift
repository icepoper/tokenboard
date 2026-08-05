import Foundation
import UserNotifications
import AppKit

/// 系统通知管理
@MainActor
final class NotificationHelper {
    static let shared = NotificationHelper()

    /// 本窗口周期内已通知的限额类型
    private var notified5hWindow: TimeInterval = 0
    private var notified7dWindow: TimeInterval = 0

    /// 当前权限状态（供 UI 显示）
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {}

    /// 请求通知权限（LSUIElement 应用需先激活才能显示系统弹窗）
    func requestPermission() async {
        // 激活 app，确保权限弹窗能正常显示
        NSApp.activate(ignoringOtherApps: true)

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            // 重新读取授权结果
            let updated = await center.notificationSettings()
            authorizationStatus = updated.authorizationStatus
        }
    }

    /// 刷新权限状态（供设置页展示）
    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// 权限状态描述
    var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined: return "未请求"
        case .denied: return "已拒绝"
        case .authorized: return "已授权"
        case .provisional: return "临时授权"
        case .ephemeral: return "会话授权"
        @unknown default: return "未知"
        }
    }

    /// 检查额度并发送预警通知
    func checkAndNotify(usage: UsageInfo) {
        // 权限未授权则不发送
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let threshold = 0.20  // 20%

        // 5h 限额检查
        if usage.per5HourRemaining < threshold, let p5hReset = usage.per5HourResetTime {
            let resetTime = p5hReset.timeIntervalSince1970
            if notified5hWindow != resetTime {
                let pct = Int(usage.per5HourRemaining * 100)
                sendNotification(
                    title: "千问 Token Plan 5h 限额预警",
                    body: "5h 限额仅剩 \(pct)%，重置时间 \(formatTime(p5hReset))"
                )
                notified5hWindow = resetTime
            }
        }

        // 7d 限额检查
        if usage.per1WeekRemaining < threshold {
            let resetTime = usage.per1WeekResetTime.timeIntervalSince1970
            if notified7dWindow != resetTime {
                let pct = Int(usage.per1WeekRemaining * 100)
                sendNotification(
                    title: "千问 Token Plan 7d 限额预警",
                    body: "7d 限额仅剩 \(pct)%，重置时间 \(formatTime(usage.per1WeekResetTime))"
                )
                notified7dWindow = resetTime
            }
        }
    }

#if DEBUG
    /// 发送测试通知（用于验证通知通道与图标，仅 Debug 构建）
    func sendTestNotification() {
        sendNotification(
            title: "TokenBoard 测试通知",
            body: "通知通道工作正常，此处应显示最新应用图标。"
        )
    }
#endif

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
