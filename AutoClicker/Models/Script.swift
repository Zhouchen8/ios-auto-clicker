import Foundation

// MARK: - 点位类型（FR1）
enum PointType: String, Codable, CaseIterable {
    case tap        // 点击
    case hold       // 长按
    case swipe      // 滑动

    var displayName: String {
        switch self {
        case .tap: return "点击"
        case .hold: return "长按"
        case .swipe: return "滑动"
        }
    }
}

// MARK: - 屏幕方向（NFR1.3）
enum ScreenOrientation: String, Codable {
    case portrait, landscape
}

// MARK: - 点位 Point（§6.1）：百分比相对坐标 + 方向
struct Point: Codable, Identifiable, Equatable {
    var id = UUID()
    var type: PointType = .tap
    /// X 百分比坐标，0-100，精度 0.1
    var xPercent: Double
    /// Y 百分比坐标，0-100，精度 0.1
    var yPercent: Double
    /// 长按/滑动时长（ms），仅 type != .tap 时使用
    var durationMs: Double?
    /// 滑动轨迹采样（百分比坐标），仅 type == .swipe 时使用
    var path: [PercentPoint]?

    struct PercentPoint: Codable, Equatable {
        var x: Double
        var y: Double
    }
}

// MARK: - 参数组（§7.1 唯一定义处）
struct ScriptParams: Codable, Equatable {
    /// 点击间隔 ms：100-60000，步进 100，默认 500
    var intervalMs: Int = 500
    /// 按住时长 ms：50-10000，步进 50，默认 150
    var holdMs: Int = 150
    /// 重复次数：1-99999，默认 100
    var repeatCount: Int = 100
    /// 无限循环
    var isInfinite: Bool = false
    /// 循环间隔 s：0-600，默认 0
    var loopGapSec: Int = 0
}

// MARK: - 脚本 Script（§6.1）
struct Script: Codable, Identifiable, Equatable {
    var id = UUID()
    /// ≤30 字符，非空
    var name: String
    /// 点位 1-20 个
    var points: [Point] = []
    var params: ScriptParams = ScriptParams()
    /// 当前方向点位集（NFR1.3：同一脚本可记录两种方向的点位集）
    var orientation: ScreenOrientation = .portrait
    var portraitPoints: [Point] = []
    var landscapePoints: [Point] = []
    /// 可选本地对照截图文件名（仅本机沙盒）
    var screenshotName: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// 当前方向下的点位列表
    var activePoints: [Point] {
        get { orientation == .landscape ? landscapePoints : portraitPoints }
        set {
            if orientation == .landscape { landscapePoints = newValue } else { portraitPoints = newValue }
            updatedAt = Date()
        }
    }
}

// MARK: - 配置进度 GuideProgress（§6.1）
struct GuideProgress: Codable, Equatable {
    var scriptId: UUID
    /// 五步向导：①确认点位 ②打开切换控制 ③录制自定手势 ④配置扫描/循环 ⑤三击启用并切回
    var steps: [Bool] = [false, false, false, false, false]
    var updatedAt: Date = Date()
}

// MARK: - 安全确认 SafetyAck（§6.1 / FR0.1）
struct SafetyAck: Codable, Equatable {
    var acceptedAt: Date?
    var version: Int = 1

    var accepted: Bool { acceptedAt != nil }
}

// MARK: - 参数校验（§7.1 唯一定义处，用于启动前校验 FR2.8）
enum ParamValidator {
    static let intervalRange = 100...60000
    static let intervalStep = 100
    static let holdRange = 50...10000
    static let holdStep = 50
    static let countRange = 1...99999
    static let loopGapRange = 0...600
    static let pointLimit = 20
    static let coordinateRange = 0.0...100.0

    static func alignInterval(_ v: Int) -> Int {
        let c = min(max(v, intervalRange.lowerBound), intervalRange.upperBound)
        return Int((Double(c) / Double(intervalStep)).rounded()) * intervalStep
    }

    static func alignHold(_ v: Int) -> Int {
        let c = min(max(v, holdRange.lowerBound), holdRange.upperBound)
        return Int((Double(c) / Double(holdStep)).rounded()) * holdStep
    }

    static func clampCount(_ v: Int) -> Int {
        min(max(v, countRange.lowerBound), countRange.upperBound)
    }

    static func clampLoopGap(_ v: Int) -> Int {
        min(max(v, loopGapRange.lowerBound), loopGapRange.upperBound)
    }

    static func roundPercent(_ v: Double) -> Double {
        (v * 10).rounded() / 10
    }

    /// 返回校验错误列表；为空表示通过（FR2.8）
    static func validate(_ script: Script) -> [String] {
        var errors: [String] = []
        if script.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("脚本名称不能为空")
        }
        if script.name.count > 30 {
            errors.append("脚本名称不能超过 30 字符")
        }
        let pts = script.activePoints
        if pts.isEmpty {
            errors.append("至少需要 1 个点位")
        }
        if pts.count > pointLimit {
            errors.append("点位不能超过 \(pointLimit) 个")
        }
        for p in pts {
            if !coordinateRange.contains(p.xPercent) || !coordinateRange.contains(p.yPercent) {
                errors.append("坐标需在 0-100% 范围内")
            }
        }
        if !intervalRange.contains(script.params.intervalMs) || script.params.intervalMs % intervalStep != 0 {
            errors.append("点击间隔需在 100-60000ms 且为 100 的整数倍")
        }
        if !holdRange.contains(script.params.holdMs) || script.params.holdMs % holdStep != 0 {
            errors.append("按住时长需在 50-10000ms 且为 50 的整数倍")
        }
        if !script.params.isInfinite && !countRange.contains(script.params.repeatCount) {
            errors.append("重复次数需在 1-99999")
        }
        if !loopGapRange.contains(script.params.loopGapSec) {
            errors.append("循环间隔需在 0-600s")
        }
        return errors
    }

    /// 单轮预计耗时（ms）：点位按住时长之和 + 相邻间隔 + 循环间隔
    static func estimatedRoundMs(_ script: Script) -> Int {
        let pts = script.activePoints
        let holds = pts.reduce(0) { $0 + Int($1.durationMs ?? Double(script.params.holdMs)) }
        let gaps = max(0, pts.count - 1) * script.params.intervalMs
        return holds + gaps + script.params.loopGapSec * 1000
    }
}

// MARK: - 运行状态机（§6.2 控制台视角）
enum RunState: Equatable {
    case idle        // 空闲
    case running     // 运行中
    case paused      // 已暂停
    case completed   // 已完成
    case stopped     // 已停止

    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .running: return "运行中"
        case .paused: return "已暂停"
        case .completed: return "已完成"
        case .stopped: return "已停止"
        }
    }
}
