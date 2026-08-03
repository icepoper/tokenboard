## Context

全新项目，无已有代码。目标平台 macOS 13+，使用 SwiftUI MenuBarExtra API。数据源为千问工作台 5 个逆向内部 API，认证方式为浏览器 Cookie + sec_token（CSRF token），用户手动从 DevTools 复制粘贴。详见 proposal.md。

## Goals / Non-Goals

**Goals:**
- 实现一个轻量（< 30MB 内存）的 macOS 菜单栏常驻应用
- 实时展示千问 Token Plan 的 5h/7d 限额消耗状态
- 凭证安全存储，不落盘明文
- 额度预警系统通知
- 零第三方依赖，纯 Apple 框架

**Non-Goals:**
- 自动获取/刷新 Cookie（v2 考虑，可能需要浏览器扩展或本地代理）
- 跨平台支持（仅 macOS）
- 用量历史趋势图表（v2 考虑，需要本地持久化历史数据）
- 团队版 Token Plan 支持（MVP 仅个人版）
- 代码签名与公证分发（MVP 阶段本地 build 即可）

## Decisions

### D1: SwiftUI MenuBarExtra 作为 UI 框架

**选择**: SwiftUI `MenuBarExtra` (macOS 13+)

**替代方案**:
- AppKit `NSStatusItem` + `NSPopover`：更灵活但代码量大，需要混合 SwiftUI/AppKit
- Tauri/Electron：太重，违背菜单栏工具"轻量"的核心价值

**理由**: MenuBarExtra 是 Apple 官方推荐的 SwiftUI 菜单栏方案，声明式 UI 与 SwiftUI 生态一致，内存占用最低（10-15MB），且项目 UI 复杂度在 SwiftUI 能力范围内。

### D2: 纯 Foundation URLSession 做 HTTP 调用

**选择**: `URLSession` + `URLRequest`，手动构造 form-urlencoded body

**替代方案**:
- Alamofire：引入第三方依赖，对于这个规模的 HTTP 调用过重
- async/await + URL Loading System：Swift 原生，足够

**理由**: 只有 5 个固定 API 端点，请求格式统一，不需要 HTTP 客户端库的抽象。async/await 让并发调用 4 个 API 的代码非常简洁（`async let` 或 `withTaskGroup`）。

### D3: Keychain 存储凭证

**选择**: Security framework 的 `SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete`

**替代方案**:
- UserDefaults：明文存储，不安全
- 文件加密：过度工程，Keychain 已提供系统级加密

**理由**: Cookie 包含登录态，等同于密码，必须用 Keychain。封装一个 `KeychainHelper` 工具类，提供 `save(key:value:)` / `read(key:)` / `delete(key:)` 三个静态方法。

### D4: Combine 作为数据流

**选择**: `@Published` + `ObservableObject` 模式，ViewModel 持有数据状态

**替代方案**:
- AsyncStream：更现代但 SwiftUI 绑定不如 @Published 直接
- 纯 @State + Task：简单场景可以，但轮询服务需要跨视图共享状态

**理由**: PollingService 作为 ObservableObject，持有 `@Published var planData: PlanData?`，所有 View 通过 `@EnvironmentObject` 或 `@ObservedObject` 观察。这是 SwiftUI 最成熟的模式。

### D5: 项目结构 — 单 Target

**选择**: 单个 Xcode target，按文件夹分层（Models / Services / Views / Utilities）

**替代方案**:
- SPM 多模块：对于 500-800 行代码过度拆分
- 多 Target（App + Framework）：无必要

**理由**: MVP 阶段代码量小，单 target 最简单。文件夹分层提供足够的代码组织。

### D6: 轮询实现 — Timer + Task

**选择**: `Timer.publish` (Combine) 或 `Task` + `Task.sleep` 循环

**理由**: 使用 `Task` + `while !Task.isCancelled { try await Task.sleep(...) }` 模式，比 Timer 更适合 async/await 风格的 API 调用，且取消语义清晰。

### D7: 进度条组件 — 自定义 SwiftUI View

**选择**: 自定义 `QuotaBar` view，使用 `GeometryReader` + `RoundedRectangle` 绘制

**替代方案**:
- `ProgressView`：系统样式，自定义空间有限
- 第三方图表库：违背零依赖原则

**理由**: 进度条 UI 简单（一个背景条 + 一个填充条 + 文字），自定义 View 20 行代码搞定，且完全可控样式。

## Risks / Trade-offs

- **[Cookie 过期]** → 用户需手动重新粘贴。MVP 阶段可接受，v2 考虑自动化方案（浏览器扩展 / 本地代理拦截）。在 UI 上明确提示过期状态和重新配置入口。

- **[API 变更]** → 千问工作台内部 API 无稳定性承诺，可能随时变更字段或路径。→ 将 API 路径和字段映射集中在 `QianwenAPI.swift` 一个文件中，变更时只需改这一处。添加响应解析的容错逻辑（字段缺失时给默认值而非 crash）。

- **[sec_token 来源不明]** → 目前不确定 sec_token 是从 cookie 中提取还是页面 meta 标签中获取。→ MVP 阶段让用户手动粘贴，后续可研究自动提取。

- **[无代码签名]** → 未签名的 .app 在 macOS 上首次打开会被 Gatekeeper 拦截。→ MVP 阶段用户右键打开即可，README 中说明。v2 考虑 Apple Developer 签名。

- **[菜单栏空间]** → 菜单栏图标过多时可能被系统隐藏。→ 使用 `NSStatusItem` 的 `isVisible` 属性或保持图标尽量小。
