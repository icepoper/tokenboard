## Purpose

封装 DeepSeek 平台 3 个接口（get_user_summary / usage/amount / usage/cost）的请求构造、userToken 认证注入与响应解析，为上层服务提供类型安全的余额与用量数据，并统一错误与失效判定。

## ADDED Requirements

### Requirement: 注入 userToken 认证

系统 SHALL 在所有 DeepSeek 平台请求头中携带 `Authorization: Bearer <userToken>`，userToken 未配置时拒绝发送请求。

#### Scenario: 认证头注入
- **WHEN** 已配置 userToken 且调用任一 DeepSeek 平台接口
- **THEN** 请求头包含 `Authorization: Bearer <userToken>`，Accept 为 application/json

#### Scenario: 凭证缺失拒绝发送
- **WHEN** userToken 为空
- **THEN** 系统返回凭证缺失错误，不发送网络请求

### Requirement: 解析账户余额

系统 SHALL 解析 get_user_summary 接口响应，提取各币种的充值余额（normal_wallets）与赠金余额（bonus_wallets），并计算总余额。

#### Scenario: 正常解析余额
- **WHEN** 接口返回 code 为 0 且 biz_data 包含 normal_wallets 与 bonus_wallets
- **THEN** 系统返回各币种的充值余额、赠金余额与总余额

#### Scenario: 余额数值为字符串
- **WHEN** 钱包 balance 字段为字符串数字（如 "110.00"）
- **THEN** 系统将其解析为数值类型，不报解析错误

#### Scenario: 多币种钱包
- **WHEN** 存在多种币种的钱包
- **THEN** 系统按币种分别返回余额，展示时优先显示人民币

### Requirement: 解析用量金额

系统 SHALL 解析 usage/amount 接口响应，提取各模型总用量（total）与按天按模型用量（days），用量类型包括输入命中缓存（PROMPT_CACHE_HIT_TOKEN）、输入未命中缓存（PROMPT_CACHE_MISS_TOKEN）、输出（RESPONSE_TOKEN）与请求数（REQUEST）。

#### Scenario: 正常解析用量
- **WHEN** 接口返回成功且 biz_data 包含 total 与 days
- **THEN** 系统返回各模型、各天的 token 用量明细

#### Scenario: 当月无调用
- **WHEN** 当月无调用且 total / days 为空数组
- **THEN** 系统返回空用量数据，不报解析错误

### Requirement: 解析消费金额

系统 SHALL 解析 usage/cost 接口响应，提取各币种下各模型总消费（total）与按天消费（days）。

#### Scenario: 正常解析消费
- **WHEN** 接口返回成功且 biz_data 包含 total 与 days
- **THEN** 系统返回各模型、各天的消费金额与对应币种

#### Scenario: 消费金额为字符串
- **WHEN** 金额字段为字符串数字
- **THEN** 系统将其解析为数值类型，不报解析错误

### Requirement: 错误码与失效判定

系统 SHALL 将 DeepSeek 平台返回的 40002 / 40003 判定为会话失效，其他非 0 code 判定为业务错误并返回错误信息。

#### Scenario: 会话失效
- **WHEN** 任一接口返回 code 40002 或 40003
- **THEN** 系统标记凭证失效，供上层展示重新登录提示

#### Scenario: 业务错误
- **WHEN** 接口返回其他非 0 code
- **THEN** 系统返回带错误信息的失败结果，不产生监控数据
