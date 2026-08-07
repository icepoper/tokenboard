## Context

当前 TokenBoard 是千问专属的单体结构：`QianwenAPI`（5 个逆向接口 + Cookie/sec_token）、`CredentialManager`（单一凭证）、`PollingService`（轮询 PlanData + 趋势）、千问专属的 `PlanData/UsageInfo/UsageTrend` 模型与 `MenuBarLabel/PopoverView/TrendChartView` 视图。DeepSeek 是预充值余额制，平台提供 3 个私人接口（get_user_summary / usage/amount / usage/cost），认证为 `Authorization: Bearer <userToken>`，返回嵌套的 code/biz_code 错误包。约束：零第三方依赖、macOS 13+、MVVM、中文注释、SF Symbols 图标。动机见 proposal.md。

## Goals / Non-Goals

**Goals:**
- 建立服务商抽象，千问与 DeepSeek 平级接入，活动服务商可切换且持久化
- DeepSeek 提供余额、今日/本月用量、近 7 天按模型 token 趋势图、低余额通知
- 千问现有功能与行为不回归

**Non-Goals:**
- 不做 Windows/Linux（已决策仅 macOS）
- 不自动从浏览器读取 userToken（本期手动粘贴，Chrome 自动导入二期评估）
- 不接入千问/DeepSeek 之外的第三个服务商（架构预留，不实现）
- 不引入任何第三方依赖

## Decisions

### D1: 服务商抽象采用协议（protocol），而非枚举分发

定义 `Provider` 协议（id、displayName、credentialStatus、snapshot、state、lastError、lastUpdated、start/stop/refresh），`ProviderManager`（ObservableObject 单例）注册全部服务商、维护活动服务商并把选择持久化到 UserDefaults。

- **理由**：新增服务商只需实现协议并注册，无需改动中心分发逻辑（开闭原则）
- **替代方案**：枚举 + switch 分发 —— 简单但每加一个服务商要改所有 switch，已否决；基类继承 —— 不契合 Swift 值语义习惯，已否决

### D2: 凭证按服务商命名空间隔离

保留 `KeychainHelper`，每个服务商使用独立命名空间 Key（千问：`qianwen_cookie` / `qianwen_sec_token`；DeepSeek：`deepseek_user_token`），各自的凭证管理器实现统一的小协议 `CredentialStoring`（status / save / clear）。

- **理由**：凭证互不覆盖，状态互不干扰；现有 KeychainHelper 零改动
- **替代方案**：单一 CredentialManager 加服务商参数 —— 状态耦合，已否决

### D3: DeepSeek API 独立实现，不复用千问客户端

新建 `DeepSeekAPI` actor，封装 3 个接口的 GET 请求（Bearer 认证头 + Accept: application/json），采用 CodexBar 验证过的嵌套容错解码（code != 0 时 data 按可选解析，避免错误包导致解码失败），并统一 40002/40003 → 凭证失效映射。

- **理由**：千问是 POST 表单 + Cookie，DeepSeek 是 GET + Bearer，认证与响应结构完全不同，强行抽象成通用 HTTP 层属于过度设计
- **替代方案**：泛化 QianwenAPI 复用 —— 接口差异大，收益低耦合高，已否决

### D4: 轮询下沉到服务商，UI 只读活动服务商快照

每个服务商内部持有自己的轮询循环与失败追踪（复用现有 `FailureTracker` 与 `resetSession` 思路）；`ProviderManager` 暴露活动服务商的快照与错误状态，`MenuBarLabel / PopoverView` 只消费活动服务商数据。

- **理由**：千问/DeepSeek 的拉取频率、数据模型、失败语义不同，集中式单轮询会变成大杂烩
- **替代方案**：单一 PollingService 按活动服务商切换目标 —— 耦合度高、回归风险大，已否决

### D5: DeepSeek 趋势数据按「近 7 天 + 按月接口合并」构建

`usage/amount` 返回按天按模型数据（days[]），但接口按月查询。取数策略：拉当前月；若近 7 天起点早于本月 1 号，则额外拉上月并按天合并，最后按 Asia/Shanghai 日历过滤出近 7 天，按模型分组渲染。

- **理由**：跨月场景（月初）不能只靠当月数据，否则月初 7 天趋势缺失
- **替代方案**：只拉当月 —— 月初趋势图缺数据，已否决；依赖服务端跨月参数 —— 无此参数，已否决

### D6: 菜单栏与弹出面板展示策略

- 菜单栏胶囊：千问显示 `QW 5h% | 7d%`；DeepSeek 显示 `DS ¥余额`（如 `DS ¥110.00`），进度环按「有余额且可用」显示满环，无余额/不可用显示警示
- 弹出面板：顶部加服务商切换器（分段控件）；DeepSeek 区块 = 余额卡片 + 今日/本月用量 + 各模型近 7 天趋势图 + 充值入口
- 千问的 `TrendChartView` 保持不动；DeepSeek 新建轻量 `ModelTrendChart`（每模型一张柱状图，复用千问图表的配色/交互风格）

- **理由**：千问与 DeepSeek 的监控语义不同（窗口额度 vs 余额），共享 UI 组件收益低
- **替代方案**：强行统一成通用快照组件 —— 抽象过度，已否决

### D7: 低余额通知

`NotificationHelper` 增加 DeepSeek 低余额分支：阈值默认 ¥20（设置页可改），记录上次通知时的余额区间，余额回升到阈值之上再跌破时允许再次通知（与千问 5h/7d 预警并存，互不影响）。

- **理由**：余额制服务的核心风险是「耗尽即失败」，阈值预警最实用
- **替代方案**：不做通知仅展示 —— 失去「主动提醒」价值，已否决

## Risks / Trade-offs

- [DeepSeek 3 个接口为私人接口，可能变更] → 解析集中在 DeepSeekAPI 内部 + 容错解码；接口变更只影响 DeepSeek 能力，不影响千问；错误信息上抛展示
- [userToken 是会话令牌，会过期] → 40002/40003 统一映射为凭证失效，UI 引导重新粘贴
- [千问迁入 Provider 抽象有回归风险] → 分阶段：先做纯重构（千问迁入，行为不变），跑通现有 38 个测试后再加 DeepSeek
- [跨月趋势合并增加复杂度] → 仅在月初场景触发上月拉取，逻辑收敛在 DeepSeekAPI 内，单测覆盖跨月用例

## Migration Plan

1. **Phase 1 纯重构**：引入 Provider 协议 + ProviderManager，千问迁入 QianwenProvider，行为不变，38 测试全绿
2. **Phase 2 DeepSeek 核心**：DeepSeekAPI + DeepSeekCredential + DeepSeekProvider 轮询（余额 + 用量 + 消费）
3. **Phase 3 UI**：服务商切换器 + DeepSeek 余额/用量/趋势图 + 设置页凭证区
4. **Phase 4 通知**：低余额预警

回滚：Provider 抽象是增量改造，默认活动服务商为千问；若 DeepSeek 出问题可单独禁用 DeepSeek Provider，千问不受影响。

## Open Questions

- 低余额阈值是否要暴露到设置页（默认 ¥20）→ 可延后，属于体验优化，不阻塞本期
- USD 账户展示优先级 → 默认优先 CNY、USD 兜底，不阻塞本期
- userToken 的 Chrome 自动导入（CodexBar 方案）→ 二期评估，不阻塞本期
