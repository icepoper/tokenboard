## 1. 项目初始化

- [x] 1.1 在 Xcode 中创建 macOS App 项目（SwiftUI lifecycle，macOS 13+ deployment target），项目名 TokenBoard
- [x] 1.2 配置 Info.plist：设置 `LSUIElement = true`（无 Dock 图标，纯菜单栏应用）
- [x] 1.3 创建文件夹结构：Models/、Services/、Views/、Utilities/
- [x] 1.4 配置 openspec/config.yaml 写入项目上下文（技术栈、约定）

## 2. 数据模型层

- [x] 2.1 定义 `SubscriptionInfo` 结构体（specCode, status, remainingDays, endTime, autoRenewFlag）
- [x] 2.2 定义 `UsageInfo` 结构体（per5HourPercentage, per5HourResetTime, per1WeekPercentage, per1WeekResetTime）
- [x] 2.3 定义 `QuotaConfig` 结构体（fiveHour, weekly，按 specCode 映射）
- [x] 2.4 定义 `ResetCard` 结构体（加油包信息）
- [x] 2.5 定义 `PlanData` 聚合结构体，组合以上四项 + 计算属性（剩余次数、剩余百分比、重置倒计时）
- [x] 2.6 定义 `APIError` 枚举（networkError, httpError, parseError, authExpired, credentialMissing）
- [x] 2.7 定义 API 响应的 Codable 解码模型（嵌套 JSON 结构映射）

## 3. 凭证管理

- [x] 3.1 实现 `KeychainHelper`：save(key:value:) / read(key:) / delete(key:) 三个静态方法
- [x] 3.2 实现 `CredentialManager` ObservableObject：@Published credentialStatus（complete/incomplete/expired）、save(cookie:secToken:)、clear()、validate() 方法
- [x] 3.3 在 CredentialManager 中集成 API 错误回调，authExpired 时自动标记状态

## 4. 千问 API 客户端

- [x] 4.1 实现 `QianwenAPI` 类：构造 form-urlencoded POST 请求的通用方法（注入 Cookie header + sec_token body 字段）
- [x] 4.2 实现 `fetchSubscription()` 方法：调用 subscription API 并解析为 SubscriptionInfo
- [x] 4.3 实现 `fetchUsage()` 方法：调用 usage API 并解析为 UsageInfo
- [x] 4.4 实现 `fetchQuotaConfig()` 方法：调用 quota-config API 并解析为 QuotaConfig
- [x] 4.5 实现 `fetchResetCards()` 方法：调用 reset-card/list API 并解析为 [ResetCard]
- [x] 4.6 实现 `fetchAll()` 方法：使用 async let 并行调用以上 4 个方法，返回 PlanData 或 APIError
- [x] 4.7 添加 10 秒超时配置和统一错误处理

## 5. 轮询服务

- [x] 5.1 实现 `PollingService` ObservableObject：@Published planData: PlanData?、@Published pollingState（idle/polling/error）
- [x] 5.2 实现 Task + Task.sleep 轮询循环，支持启动/停止/取消
- [x] 5.3 实现手动刷新方法 refresh()，立即触发一次 fetchAll
- [x] 5.4 实现错误重试逻辑：单次失败后 5 秒重试 1 次，连续 3 周期失败标记连接异常
- [x] 5.5 实现轮询间隔可配置（UserDefaults 持久化），修改后立即生效
- [x] 5.6 应用启动时检测凭证完整性，完整则立即执行首次拉取

## 6. 菜单栏 UI — 状态栏

- [x] 6.1 在 App 入口声明 MenuBarExtra，绑定 PollingService 和 CredentialManager 为 EnvironmentObject
- [x] 6.2 实现 `MenuBarLabel` view：根据状态显示百分比 / "--" / "?" / "!"

## 7. 菜单栏 UI — 弹出面板

- [x] 7.1 实现 `PopoverView` 主布局：套餐信息区 + 限额区 + 加油包区 + 操作按钮区
- [x] 7.2 实现套餐信息区：显示 specCode、status、remainingDays、到期日期
- [x] 7.3 实现 `QuotaBar` 组件：标签 + 进度条（GeometryReader + RoundedRectangle）+ 剩余百分比 + 剩余/总次数 + 重置倒计时
- [x] 7.4 在限额区使用 QuotaBar 分别展示 5h 和 7d 限额
- [x] 7.5 实现加油包区：空列表时显示"暂无加油包"，有数据时列表展示
- [x] 7.6 实现操作按钮区：刷新按钮（带加载动画）、设置按钮、打开工作台按钮（NSWorkspace.open）

## 8. 设置窗口

- [x] 8.1 实现 `SettingsView` 窗口：Cookie 多行输入框 + sec_token 单行输入框 + 保存/清除按钮
- [x] 8.2 保存逻辑：调用 CredentialManager.save()，清空输入框，显示"已保存"提示，触发轮询启动
- [x] 8.3 清除逻辑：调用 CredentialManager.clear()，停止轮询
- [x] 8.4 实现轮询间隔选择器（Picker，可选 15/30/60/120/300 秒）
- [x] 8.5 实现开机自启开关（ServiceManagement framework 的 SMAppService）

## 9. 系统通知

- [x] 9.1 请求通知权限（UNUserNotificationCenter）
- [x] 9.2 实现额度预警逻辑：轮询数据更新时检查 5h/7d 剩余是否 < 20%，低于阈值且本窗口周期未通知过则发送通知
- [x] 9.3 窗口重置后清除通知标记，允许下一轮通知

## 10. 集成测试与验证

- [x] 10.1 在 Xcode 中 build 并运行，验证菜单栏图标正常显示
- [x] 10.2 粘贴真实 Cookie 和 sec_token，验证 API 调用成功、数据正确展示
- [x] 10.3 验证弹出面板所有区域数据渲染正确
- [x] 10.4 验证手动刷新、设置保存/清除、轮询间隔修改功能
- [x] 10.5 验证凭证过期时 UI 状态正确切换
- [x] 10.6 验证额度预警通知触发
