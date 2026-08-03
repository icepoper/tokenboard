## Purpose

封装千问工作台 5 个逆向 API 的 HTTP 调用逻辑，提供类型安全的 Swift 接口供上层服务消费，屏蔽请求构造、认证注入、响应解析等底层细节。

## ADDED Requirements

### Requirement: 构造统一请求格式

系统 SHALL 将所有 API 调用封装为 POST 请求，Content-Type 为 `application/x-www-form-urlencoded`，请求体包含 `product`、`action`、`sec_token`、`region`、`params` 五个表单字段。其中 `params` 为 JSON 字符串，包含 `Api`、`Data`、`V` 三个键。

#### Scenario: 业务 API 请求构造
- **WHEN** 调用 subscription / usage / quota-config / reset-card 接口
- **THEN** 请求发往 `https://cs-data.qianwenai.com/data/api.json`，product 为 `sfm_bailian`，action 为 `BroadScopeAspnGateway`，params.Data 包含 `cornerstoneParam` 对象

#### Scenario: BSS API 请求构造
- **WHEN** 调用 QueryAvailableInstances 接口
- **THEN** 请求发往 `https://platform-home.qianwenai.com/data/api.json`，product 为 `BssOpenApi`，action 为 `QueryAvailableInstances`，params 包含 InstanceIDs、ProductCode、ProductType、PageNum、PageSize

### Requirement: 注入认证凭证

系统 SHALL 在每个请求的 Cookie header 中携带用户提供的完整 Cookie 字符串，在表单 body 中携带 sec_token。

#### Scenario: 凭证完整时正常发送
- **WHEN** Cookie 和 sec_token 均已配置
- **THEN** 请求 header 包含 `Cookie: <用户提供的cookie>`，body 包含 `sec_token=<用户提供的token>`

#### Scenario: 凭证缺失时拒绝发送
- **WHEN** Cookie 或 sec_token 为空
- **THEN** 系统 SHALL 返回凭证缺失错误，不发送网络请求

### Requirement: 解析 subscription 响应

系统 SHALL 解析 subscription API 响应，提取 specCode（套餐等级）、status（状态）、remainingDays（剩余天数）、endTime（到期时间戳）、autoRenewFlag（自动续费标志）。

#### Scenario: 正常解析套餐信息
- **WHEN** API 返回 code 为 200 且 data.DataV2.data.code 为 SUCCESS
- **THEN** 系统返回包含 specCode、status、remainingDays、endTime、autoRenewFlag 的结构体

#### Scenario: API 返回错误
- **WHEN** API 返回非 SUCCESS 的 code
- **THEN** 系统 SHALL 返回包含错误信息的失败结果

### Requirement: 解析 usage 响应

系统 SHALL 解析 usage API 响应，提取 per5HourPercentage（5h 已用百分比）、per5HourResetTime（5h 重置时间戳）、per1WeekPercentage（7d 已用百分比）、per1WeekResetTime（7d 重置时间戳）。

#### Scenario: 正常解析用量数据
- **WHEN** API 返回成功响应
- **THEN** 系统返回包含四个百分比/时间戳字段的结构体，百分比为 0.0-1.0 的 Double 值

### Requirement: 解析 quota-config 响应

系统 SHALL 解析 quota-config API 响应，提取当前套餐等级对应的 five_hour 和 weekly 配额上限值。

#### Scenario: 根据套餐等级提取配额
- **WHEN** 用户套餐为 standard 且 API 返回成功
- **THEN** 系统返回 five_hour=3000、weekly=10000

### Requirement: 解析 reset-card 响应

系统 SHALL 解析 reset-card/list API 响应，返回加油包列表（可为空数组）。

#### Scenario: 无加油包
- **WHEN** API 返回 data 为空数组
- **THEN** 系统返回空列表

#### Scenario: 有加油包
- **WHEN** API 返回 data 包含加油包对象
- **THEN** 系统返回包含加油包信息的列表

### Requirement: 网络超时与错误处理

系统 SHALL 为每个 API 请求设置 10 秒超时。网络错误、HTTP 非 200 状态码、JSON 解析失败 SHALL 被捕获并返回统一的错误类型。

#### Scenario: 请求超时
- **WHEN** 网络请求超过 10 秒未响应
- **THEN** 系统返回超时错误

#### Scenario: HTTP 错误状态码
- **WHEN** 服务器返回 4xx 或 5xx 状态码
- **THEN** 系统返回包含状态码的错误
