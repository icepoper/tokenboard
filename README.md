# TokenBoard

macOS 菜单栏小工具，实时监控千问 Token Plan 的 5h/7d 限额消耗情况。

## 功能

- 菜单栏实时显示最紧张限额的剩余百分比
- 弹出面板展示 5h/7d 限额进度条、剩余次数、重置倒计时
- 套餐信息（等级、状态、剩余天数、到期日期）
- 加油包信息
- 额度低于 20% 时系统通知预警
- 凭证安全存储（macOS Keychain）
- 可配置轮询间隔（15-300 秒）
- 胶囊背景颜色可自定义（设置窗口实时生效）
- 开机自启支持
- 一键退出（弹出面板右下角电源按钮）

## 系统要求

- macOS 13.0+
- Xcode 15.0+

## 构建

```bash
# 1. 安装 xcodegen（如果还没有）
brew install xcodegen

# 2. 生成 Xcode 项目
xcodegen generate

# 3. 用 Xcode 打开并构建
open TokenBoard.xcodeproj
# 在 Xcode 中按 Cmd+R 运行
```

## 使用

1. 启动应用后，菜单栏会出现 TokenBoard 图标
2. 点击图标，在弹出面板中点击设置按钮
3. 从浏览器 DevTools 复制 Cookie 和 sec_token：
   - 打开 [千问 Token Plan 页面](https://platform.qianwenai.com/home/billing/subscription/token-plan-individual)
   - F12 → Network → 刷新页面 → 点击任意请求 → Headers 标签复制 Cookie
   - Payload 标签复制 sec_token
4. 粘贴到设置窗口并保存
5. 数据会自动开始刷新

## 项目结构

```
TokenBoard/
├── TokenBoardApp.swift          # App 入口 + MenuBarExtra
├── Models/
│   ├── PlanData.swift           # 数据模型（套餐/用量/配额/加油包）
│   ├── APIResponse.swift        # API 响应 Codable 解码
│   └── APIError.swift           # 错误类型
├── Services/
│   ├── QianwenAPI.swift         # 千问 API 客户端（5 个接口）
│   ├── PollingService.swift     # 后台轮询服务
│   └── CredentialManager.swift  # 凭证管理
├── Views/
│   ├── MenuBarLabel.swift       # 菜单栏图标+文字
│   ├── PopoverView.swift        # 弹出面板
│   ├── QuotaBar.swift           # 限额进度条组件
│   └── SettingsView.swift       # 设置窗口
├── Utilities/
│   ├── KeychainHelper.swift     # Keychain 安全存储
│   └── NotificationHelper.swift # 系统通知
└── TokenBoard.entitlements      # 网络权限
```

## 技术栈

- Swift 5.9+ / SwiftUI
- 零第三方依赖
- XcodeGen 项目管理
- OpenSpec 规格驱动开发

## License

MIT
