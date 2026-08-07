## Purpose

定义服务商抽象层与活动服务商切换机制，使菜单栏胶囊、弹出面板、设置页与轮询服务能够承载多个模型服务商（千问 / DeepSeek），并为后续扩展更多服务商提供统一接入方式。

## ADDED Requirements

### Requirement: 服务商抽象协议

系统 SHALL 提供统一的 Provider 抽象，屏蔽不同服务商的 API 客户端、凭证模型与数据模型的差异，上层 UI 与轮询服务仅依赖协议接口。

#### Scenario: 多个服务商实现同一协议
- **WHEN** 注册千问与 DeepSeek 两个服务商
- **THEN** 两者均遵循同一 Provider 协议，上层模块不感知具体服务商实现

#### Scenario: 服务商能力声明
- **WHEN** 任意服务商实现 Provider 协议
- **THEN** 系统可读取其标识、显示名称、凭证状态、监控快照与错误信息

### Requirement: 活动服务商切换

系统 SHALL 维护当前活动服务商，切换后菜单栏胶囊、弹出面板与轮询目标随之切换，且选择被持久化。

#### Scenario: 切换服务商
- **WHEN** 用户在设置页或弹出面板将活动服务商从千问切换为 DeepSeek
- **THEN** 菜单栏与弹出面板展示 DeepSeek 的监控数据，轮询服务按 DeepSeek 刷新

#### Scenario: 活动服务商持久化
- **WHEN** 用户切换活动服务商后重启应用
- **THEN** 应用沿用上次选择的活动服务商

### Requirement: 凭证按服务商隔离

系统 SHALL 为每个服务商独立存储与校验凭证，服务商之间互不干扰。

#### Scenario: 凭证独立互不影响
- **WHEN** 千问凭证完整而 DeepSeek 凭证缺失
- **THEN** 千问正常监控，DeepSeek 展示未配置凭证的提示，两者状态互不影响

#### Scenario: 切换服务商后展示对应凭证状态
- **WHEN** 活动服务商切换为 DeepSeek 且其凭证失效
- **THEN** 弹出面板展示凭证失效提示，而非其他服务商的数据

### Requirement: 轮询按活动服务商执行

系统 SHALL 仅轮询活动服务商的数据，不向非活动服务商发送请求。

#### Scenario: 只轮询活动服务商
- **WHEN** 活动服务商为 DeepSeek
- **THEN** 轮询仅请求 DeepSeek 接口，不请求千问接口

#### Scenario: 切换后立即刷新
- **WHEN** 活动服务商切换完成
- **THEN** 系统立即按新活动服务商拉取一次数据
