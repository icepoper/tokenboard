## Purpose

管理 DeepSeek 平台会话凭证 userToken，提供输入引导、Keychain 安全存储、凭证状态（未配置 / 已配置 / 失效）管理，支撑多服务商架构下的凭证隔离。

## ADDED Requirements

### Requirement: userToken 输入与存储

系统 SHALL 允许用户在设置页粘贴 userToken，并安全存储到 Keychain。

#### Scenario: 保存凭证
- **WHEN** 用户在设置页粘贴 userToken 并保存
- **THEN** 凭证写入 Keychain，凭证状态为已配置

#### Scenario: 清空凭证
- **WHEN** 用户清空已保存的 userToken
- **THEN** 系统从 Keychain 删除凭证，状态为未配置

### Requirement: 凭证状态管理

系统 SHALL 维护凭证的 未配置 / 已配置 / 失效 三种状态，失效状态由 API 错误码（40002 / 40003）触发。

#### Scenario: 会话失效触发状态变更
- **WHEN** DeepSeek 接口返回 40002 或 40003
- **THEN** 凭证状态转为失效，弹出面板与设置页提示用户重新粘贴 userToken

#### Scenario: 重新保存后恢复
- **WHEN** 用户重新粘贴有效 userToken
- **THEN** 凭证状态恢复为已配置，并立即重新拉取数据

### Requirement: 凭证获取引导

系统 SHALL 在 DeepSeek 凭证设置区域提供获取 userToken 的操作指引。

#### Scenario: 展示获取步骤
- **WHEN** 用户打开 DeepSeek 凭证设置
- **THEN** 系统显示引导说明：浏览器登录 platform.deepseek.com → DevTools → Application → Local Storage → https://platform.deepseek.com → 复制 userToken 字段值
