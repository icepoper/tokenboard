import Foundation

/// 连续失败计数器：决定何时重建连接池、何时进入错误状态。
/// 纯值类型，便于单元测试。
struct FailureTracker {
    private(set) var consecutiveFailures = 0

    /// 连续失败达到该次数后进入 error 状态
    let maxConsecutiveFailures: Int

    /// 连续失败达到该次数后重建 URLSession（丢弃可能失效的连接池）
    let resetSessionThreshold: Int

    init(maxConsecutiveFailures: Int = 3, resetSessionThreshold: Int = 2) {
        self.maxConsecutiveFailures = maxConsecutiveFailures
        self.resetSessionThreshold = resetSessionThreshold
    }

    struct Decision {
        /// 是否应重建连接池
        let shouldResetSession: Bool
        /// 是否应延迟重试一次（仅首次失败）
        let shouldRetry: Bool
        /// 是否应进入错误状态
        let isError: Bool
    }

    /// 记录一次失败，返回本次失败后的处置决策
    mutating func recordFailure() -> Decision {
        consecutiveFailures += 1
        return Decision(
            shouldResetSession: consecutiveFailures >= resetSessionThreshold,
            shouldRetry: consecutiveFailures == 1,
            isError: consecutiveFailures >= maxConsecutiveFailures
        )
    }

    /// 记录一次成功，清零计数
    mutating func recordSuccess() {
        consecutiveFailures = 0
    }

    /// 是否处于持续失败状态（供 UI 展示错误提示）
    var isFailing: Bool { consecutiveFailures >= resetSessionThreshold }
}
