## Purpose

提供后台定时轮询能力，按可配置间隔调用千问 API 获取最新数据，管理轮询生命周期（启动/停止/手动刷新），并将数据变化通知 UI 层。

## ADDED Requirements

### Requirement: 定时轮询

系统 SHALL 在凭证完整时，按默认 60 秒间隔自动调用 API 获取 subscription、usage、quota-config、reset-card 四项数据。

#### Scenario: 正常轮询周期
- **WHEN** 凭证完整且轮询已启动
- **THEN** 系统每 60 秒发起一次完整数据拉取（4 个 API 并行调用）

#### Scenario: 凭证不完整时不轮询
- **WHEN** 凭证缺失或过期
- **THEN** 系统不发起网络请求，轮询计时器暂停

### Requirement: 手动刷新

系统 SHALL 提供手动刷新接口，用户点击刷新按钮时立即触发一次数据拉取，不受轮询间隔限制。

#### Scenario: 用户点击刷新
- **WHEN** 用户在弹出面板点击刷新按钮
- **THEN** 系统立即发起一次 API 调用，完成后更新 UI 数据

### Requirement: 轮询间隔可配置

系统 SHALL 允许用户在设置中修改轮询间隔，范围 15-300 秒，默认 60 秒。修改后立即生效。

#### Scenario: 用户修改间隔为 30 秒
- **WHEN** 用户在设置中将轮询间隔改为 30 秒
- **THEN** 下一次轮询在 30 秒后触发

### Requirement: 应用启动时自动首次拉取

系统 SHALL 在应用启动且凭证完整时，立即执行一次数据拉取，不等首个轮询周期。

#### Scenario: 启动时有凭证
- **WHEN** 应用启动且 Keychain 中有完整凭证
- **THEN** 立即发起 API 调用，菜单栏在数据返回后更新

### Requirement: 错误重试策略

系统 SHALL 在 API 调用失败时，在当前轮询周期内最多重试 1 次（间隔 5 秒）。连续 3 次轮询周期均失败后，将状态标记为连接异常。

#### Scenario: 单次请求失败
- **WHEN** 某次 API 调用网络超时
- **THEN** 5 秒后重试一次，若重试成功则正常更新数据

#### Scenario: 连续失败
- **WHEN** 连续 3 个轮询周期均失败
- **THEN** 菜单栏显示错误状态图标，弹出面板显示"连接异常"

### Requirement: 数据变化通知

系统 SHALL 在每次成功拉取数据后，将最新数据发布给 UI 层（通过 Combine 或 async stream）。

#### Scenario: 数据更新
- **WHEN** API 返回新数据
- **THEN** UI 层收到包含 subscription、usage、quota-config、reset-card 的完整数据包
