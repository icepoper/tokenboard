## Why

用户同时使用千问 Token Plan 与 DeepSeek API。DeepSeek 是预充值余额制，用量页（platform.deepseek.com/usage）没有实时感知入口，余额耗尽会导致 API 调用直接失败。需要把 DeepSeek 的余额、消费与 token 用量纳入 TokenBoard 实时监控；同时当前代码是千问专属架构，扩展成本高，需要升级为多服务商架构，为后续接入更多模型服务商打基础。

## What Changes

- **多服务商架构**：定义 `Provider` 抽象（协议 + ProviderManager），千问作为首个 Provider 迁入，DeepSeek 作为第二个 Provider 接入
- **服务商切换**：菜单栏胶囊、弹出面板、设置页支持在千问 / DeepSeek 之间切换，各服务商展示各自的监控数据
- **DeepSeek 平台会话认证**：接入用户从浏览器 localStorage 获取的 `userToken`，Keychain 安全存储
- **DeepSeek 余额监控**：调用 `users/get_user_summary` 接口，展示充值余额 / 赠金余额 / 总余额与可用状态
- **DeepSeek 详细用量**：调用 `usage/amount` + `usage/cost` 接口，展示今日 / 本月 tokens 与消费金额、请求数、各模型用量
- **近 7 天按模型 token 趋势图**：从 `usage/amount` 的按天数据提取近 7 天各模型 token 趋势，多个模型渲染多张趋势图
- **低余额预警通知**：余额低于阈值时发送 macOS 系统通知
- 现有千问模块（QianwenAPI / CredentialManager / PollingService / MenuBarLabel / PopoverView / SettingsView / TrendChartView / NotificationHelper）重构为服务商化

## Capabilities

### New Capabilities

- `multi-provider-architecture`: 服务商抽象层，定义 Provider 协议、ProviderManager 单例、活动服务商切换，以及菜单栏 / 弹出面板 / 设置页的服务商化改造
- `deepseek-api-client`: DeepSeek 平台接口客户端，封装 user_summary / usage/amount / usage/cost 三个接口的请求构造、userToken 认证注入与响应解析
- `deepseek-credential`: DeepSeek userToken 凭证管理，输入、Keychain 存储、失效检测（40002/40003 等错误码判定）
- `deepseek-usage-view`: DeepSeek 展示层，余额卡片、今日 / 本月用量、按模型近 7 天 token 趋势图（多模型多图）、低余额通知

### Modified Capabilities

（无。主规格尚未从 init-tokenboard-mvp 同步，现有行为变更统一体现在上述新能力规格中）

## Impact

- **重构文件**: QianwenAPI 迁入 Provider 抽象；CredentialManager 改为按服务商管理凭证；PollingService 改为按活动服务商轮询；MenuBarLabel / PopoverView / SettingsView / TrendChartView / NotificationHelper 服务商化
- **新文件**: Provider 协议、ProviderManager、DeepSeekAPI、DeepSeekCredential、DeepSeek 视图组件
- **外部 API**: DeepSeek 平台私人接口（非公开，可能变更）：`platform.deepseek.com/api/v0/users/get_user_summary`、`/api/v0/usage/amount`、`/api/v0/usage/cost`；认证为 `Authorization: Bearer <userToken>`，userToken 由用户在浏览器 localStorage 获取
- **依赖**: 保持零第三方依赖（纯 SwiftUI + Foundation + Security）
- **安全**: userToken 存 macOS Keychain，不落盘明文
- **系统要求**: macOS 13+ 不变
