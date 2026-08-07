## 1. 多服务商架构（纯重构，千问迁入，行为不变）

- [x] 1.1 定义 `Provider` 协议：id、displayName、credentialStatus、snapshot、state、lastError、lastUpdated、start / stop / refresh
- [x] 1.2 定义 `ProviderSnapshot` 模型族：QianwenSnapshot（包装现有 PlanData + 趋势）、DeepSeekSnapshot（余额 + 用量摘要 + 按天按模型趋势）
- [x] 1.3 实现 `ProviderManager`（ObservableObject 单例）：注册服务商、活动服务商切换、选择持久化到 UserDefaults
- [x] 1.4 将 QianwenAPI 与现有 PollingService 逻辑迁入 `QianwenProvider`，对外行为不变，默认活动服务商为千问
- [x] 1.5 凭证按服务商隔离：定义 `CredentialStoring` 协议，重构为 `QianwenCredentialStore` 与 `DeepSeekCredentialStore`，Keychain 命名空间隔离
- [x] 1.6 现有 38 个测试保持全绿；新增 ProviderManager 单测（切换、持久化、凭证隔离、只轮询活动服务商）

## 2. DeepSeek 核心

- [x] 2.1 实现 `DeepSeekAPI` actor 与 Bearer 认证注入：请求头 `Authorization: Bearer <userToken>`，凭证缺失拒绝发送
- [x] 2.2 实现 get_user_summary 余额解析：normal_wallets / bonus_wallets、字符串数值容错、多币种（优先 CNY）
- [x] 2.3 实现 usage/amount 用量解析：total（各模型）+ days（按天按模型）、token 类型映射（PROMPT_CACHE_HIT/MISS、RESPONSE、REQUEST）、空数据容错
- [x] 2.4 实现 usage/cost 消费解析：各币种 total + days、字符串数值容错
- [x] 2.5 实现错误映射：40002 / 40003 → 凭证失效（expired），其他非 0 code → 业务错误上抛
- [x] 2.6 实现 `DeepSeekCredential`：userToken 输入、Keychain 存储、未配置 / 已配置 / 失效状态管理、获取引导说明
- [x] 2.7 实现 `DeepSeekProvider` 轮询：余额 + 用量 + 消费；复用 FailureTracker 失败重试；近 7 天跨月自动拉上月合并（按 Asia/Shanghai 日历）
- [x] 2.8 DeepSeek 单测：余额 / 用量 / 消费解析、错误码映射、跨月合并、近 7 天按模型分组

## 3. DeepSeek UI 与通知

- [x] 3.1 弹出面板顶部加服务商切换器（分段控件），切换即刷新并持久化
- [x] 3.2 菜单栏胶囊支持 DeepSeek：显示 `DS ¥余额`，进度环按余额可用性展示（无余额 / 不可用警示）
- [x] 3.3 弹出面板 DeepSeek 余额卡片：总余额 / 充值 / 赠金 / 币种 / 可用状态，余额为零或不可用时展示充值引导
- [x] 3.4 弹出面板 DeepSeek 用量区：今日与本月 tokens、消费金额、请求数、各模型用量明细
- [x] 3.5 实现 `ModelTrendChart`：每模型近 7 天 token 柱状图（多模型多图），无数据提示、拉取失败保留旧图并显示原因
- [x] 3.6 设置页：服务商选择 + DeepSeek 凭证区（userToken 粘贴、获取引导、清空、失效提示）
- [x] 3.7 低余额通知：总余额低于 ¥20 时发送系统通知，余额回升到阈值以上再跌破时允许再次通知

## 4. 验证与发布

- [x] 4.1 联调：用真实 userToken 验证余额 / 用量 / 趋势拉取与展示
- [x] 4.2 回归：千问监控不受影响（全量单测 + 手动验证千问面板与趋势图）
- [x] 4.3 更新 CHANGELOG / README，提交 + 打 tag + 发布新版本
