## Why

千问 Token Plan 用户需要频繁打开浏览器查看额度消耗情况，无法在编码/工作时实时感知 5 小时和 7 天滑动窗口的剩余额度。当额度耗尽时 API 调用会直接失败，影响工作流。需要一个 macOS 菜单栏常驻工具，让用户一眼看到实时消耗状态，并在额度即将耗尽时主动提醒。

## What Changes

- 新建 SwiftUI macOS 应用，使用 `MenuBarExtra` 在系统菜单栏显示千问 Token Plan 状态摘要
- 实现千问工作台内部 API 的逆向调用客户端，通过 Cookie + sec_token 认证获取套餐信息、实时用量百分比、配额配置、加油包列表
- 实现后台定时轮询服务（默认 60 秒间隔），自动刷新数据
- 弹出面板展示 5h/7d 限额进度条、剩余天数、重置倒计时、加油包信息
- 设置页面支持粘贴 Cookie 和 sec_token，使用 Keychain 安全存储
- 菜单栏图标动态显示当前最紧张的限额百分比
- 额度低于阈值时发送 macOS 系统通知

## Capabilities

### New Capabilities

- `qianwen-api-client`: 千问工作台 API 客户端，封装 5 个逆向接口的调用、请求构造、响应解析
- `credential-management`: 凭证管理，Cookie 和 sec_token 的输入、Keychain 存储、过期检测
- `polling-service`: 后台轮询服务，定时拉取数据、错误重试、状态管理
- `menu-bar-ui`: 菜单栏 UI，包括状态栏图标/文字、弹出面板、设置页面、系统通知

### Modified Capabilities

（无，全新项目）

## Impact

- **新代码**: 全新 SwiftUI macOS 项目，约 500-800 行 Swift 代码
- **外部依赖**: 无第三方依赖，纯 SwiftUI + Foundation + Security (Keychain)
- **系统要求**: macOS 13+ (MenuBarExtra API)
- **外部 API**: 依赖千问工作台非公开 API（cs-data.qianwenai.com / platform-home.qianwenai.com），接口变更时需适配
- **安全**: 用户凭证存储在 macOS Keychain，不落盘明文
