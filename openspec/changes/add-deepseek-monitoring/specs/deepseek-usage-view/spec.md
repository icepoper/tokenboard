## Purpose

展示 DeepSeek 账户余额与详细用量，提供近 7 天按模型的 token 趋势图（多模型多图）与低余额预警通知，让用户在菜单栏弹出面板中实时掌握 DeepSeek 消耗情况。

## ADDED Requirements

### Requirement: 余额展示

系统 SHALL 展示 DeepSeek 总余额、充值余额、赠金余额、币种与可用状态。

#### Scenario: 有余额且可用
- **WHEN** 总余额大于 0 且 is_available 为 true
- **THEN** 面板展示总余额，并拆分展示充值余额与赠金余额

#### Scenario: 余额为零或不可用
- **WHEN** 总余额为 0 或 is_available 为 false
- **THEN** 面板提示余额不足或不可用，并展示充值引导文案

### Requirement: 详细用量展示

系统 SHALL 展示今日 / 本月的 tokens 用量、消费金额与请求数，以及各模型用量分布。

#### Scenario: 本月有调用
- **WHEN** 本月存在调用记录
- **THEN** 面板展示今日与本月 tokens、消费金额、请求数，以及各模型用量明细

#### Scenario: 本月无调用
- **WHEN** 本月无调用记录
- **THEN** 面板展示无用量数据提示，不显示空值

### Requirement: 近 7 天按模型 token 趋势图

系统 SHALL 从按天数据中提取近 7 天各模型的 token 用量，并为每个产生调用的模型渲染一张趋势图。

#### Scenario: 多个模型多张图
- **WHEN** 近 7 天有 3 个模型产生调用
- **THEN** 渲染 3 张趋势图，每张图展示对应模型每日 token 总量

#### Scenario: 单模型单张图
- **WHEN** 近 7 天只有 1 个模型产生调用
- **THEN** 渲染 1 张趋势图

#### Scenario: 近 7 天无调用
- **WHEN** 近 7 天无任何调用
- **THEN** 显示暂无数据提示，不渲染空图

#### Scenario: 数据缺失时保留旧图
- **WHEN** 趋势数据拉取失败
- **THEN** 保留上次成功拉取的趋势图，并展示加载失败原因

### Requirement: 低余额预警通知

系统 SHALL 在总余额低于阈值（默认 20 元）时发送 macOS 系统通知，且同一余额区间不重复通知。

#### Scenario: 余额跌破阈值
- **WHEN** 总余额低于阈值且此前未在低于阈值区间通知过
- **THEN** 发送低余额预警系统通知

#### Scenario: 回升后再跌破可再次通知
- **WHEN** 余额回升到阈值以上后再次跌破阈值
- **THEN** 系统可再次发送低余额预警通知
