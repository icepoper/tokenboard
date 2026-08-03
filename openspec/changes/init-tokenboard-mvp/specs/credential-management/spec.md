## Purpose

管理用户从浏览器复制的千问工作台 Cookie 和 sec_token，提供安全存储（Keychain）、读取、清除和过期检测能力，确保凭证不以明文形式落盘。

## ADDED Requirements

### Requirement: 安全存储凭证

系统 SHALL 使用 macOS Keychain 存储用户提供的 Cookie 字符串和 sec_token，不以明文写入文件系统或 UserDefaults。

#### Scenario: 保存凭证到 Keychain
- **WHEN** 用户在设置页面粘贴 Cookie 和 sec_token 并点击保存
- **THEN** 系统将两项凭证分别存入 Keychain，设置页面输入框清空

#### Scenario: 应用重启后凭证持久化
- **WHEN** 用户保存凭证后退出并重新打开应用
- **THEN** 系统能从 Keychain 读取凭证，无需重新输入

### Requirement: 读取凭证

系统 SHALL 提供同步读取接口，返回当前存储的 Cookie 和 sec_token（可选值）。

#### Scenario: 凭证已存储
- **WHEN** Keychain 中存在凭证
- **THEN** 读取接口返回非空的 Cookie 和 sec_token 字符串

#### Scenario: 凭证未存储
- **WHEN** Keychain 中无凭证（首次使用或已清除）
- **THEN** 读取接口返回 nil

### Requirement: 清除凭证

系统 SHALL 提供清除接口，从 Keychain 中删除所有已存储的凭证。

#### Scenario: 用户主动清除
- **WHEN** 用户在设置页面点击"清除凭证"
- **THEN** Keychain 中的 Cookie 和 sec_token 被删除，应用状态变为未配置

### Requirement: 凭证完整性校验

系统 SHALL 在每次 API 调用前检查 Cookie 和 sec_token 是否均非空。任一为空时 SHALL 标记凭证状态为不完整。

#### Scenario: Cookie 为空
- **WHEN** Cookie 为 nil 或空字符串，sec_token 有值
- **THEN** 凭证状态为不完整，API 客户端拒绝发送请求

#### Scenario: 两项均有值
- **WHEN** Cookie 和 sec_token 均非空
- **THEN** 凭证状态为完整，允许 API 调用

### Requirement: 凭证过期检测

系统 SHALL 在 API 返回认证失败（HTTP 401/403 或业务层登录过期错误码）时，将凭证状态标记为已过期，并通知 UI 层提示用户重新粘贴。

#### Scenario: API 返回登录过期
- **WHEN** API 响应包含登录过期错误
- **THEN** 系统将凭证标记为过期，菜单栏显示警告状态
