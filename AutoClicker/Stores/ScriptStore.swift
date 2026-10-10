import Foundation
import Combine
import UIKit
import UserNotifications

/// 全局数据存储 + 运行节拍状态机（§6.2 / FR3）
@MainActor
final class ScriptStore: ObservableObject {
    // MARK: - Published 状态
    @Published var scripts: [Script] = []
    @Published var safetyAck = SafetyAck()
    @Published var runState: RunState = .idle
    @Published var activeScript: Script?
    @Published var currentPointIndex: Int = 0
    @Published var currentRound: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var isBackgrounded: Bool = false

    // MARK: - 私有持久化
    private let defaults = UserDefaults.standard
    private let scriptsKey = "autoclicker.scripts.v1"
    private let ackKey = "autoclicker.safetyAck.v1"
    private var beatTimer: Timer?
    private var runStartAt: Date?
    private var totalRounds: Int = 0
    private var isLoopInfinite: Bool = false

    init() {
        load()
        observeLifecycle()
    }

    // MARK: - 启动引导
    func bootstrap() {
        requestNotificationPermissionIfNeeded()
        registerAppShortcutsIfAvailable()
    }

    // MARK: - 持久化
    private func load() {
        if let data = defaults.data(forKey: scriptsKey),
           let decoded = try? JSONDecoder().decode([Script].self, from: data) {
            scripts = decoded
        }
        if let data = defaults.data(forKey: ackKey),
           let decoded = try? JSONDecoder().decode(SafetyAck.self, from: data) {
            safetyAck = decoded
        }
    }

    private func persistScripts() {
        if let data = try? JSONEncoder().encode(scripts) {
            defaults.set(data, forKey: scriptsKey)
        }
    }

    func persistAck() {
        if let data = try? JSONEncoder().encode(safetyAck) {
            defaults.set(data, forKey: ackKey)
        }
    }

    // MARK: - 安全确认（FR0.1）
    func acceptSafety() {
        safetyAck.acceptedAt = Date()
        safetyAck.version = 1
        persistAck()
    }

    // MARK: - 脚本 CRUD
    func createScript(named name: String = "未命名脚本") -> Script {
        var s = Script(name: name)
        s.portraitPoints = []
        s.landscapePoints = []
        scripts.insert(s, at: 0)
        persistScripts()
        return s
    }

    func updateScript(_ script: Script) {
        if let idx = scripts.firstIndex(where: { $0.id == script.id }) {
            var updated = script
            updated.updatedAt = Date()
            scripts[idx] = updated
            persistScripts()
        }
    }

    func deleteScript(_ script: Script) {
        scripts.removeAll { $0.id == script.id }
        persistScripts()
    }

    func duplicateScript(_ script: Script) {
        var copy = script
        copy.id = UUID()
        copy.name = script.name + " 副本"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        scripts.insert(copy, at: 0)
        persistScripts()
    }

    // MARK: - 运行控制（FR3）
    func start(script: Script) {
        let errors = ParamValidator.validate(script)
        guard errors.isEmpty else { return }

        // 前置条件：切换到控制需开启（UIAccessibility 无公共读取项，用可用性提示）
        let switchRunning = UIAccessibility.isSwitchControlRunning
        if !switchRunning {
            // 仍允许启动：App 内节拍与控制台可用，真实点击依赖系统切换控制（FR3.2 引导）
        }

        activeScript = script
        currentPointIndex = 0
        currentRound = 0
        elapsedSeconds = 0
        totalRounds = script.params.isInfinite ? 0 : script.params.repeatCount
        isLoopInfinite = script.params.isInfinite
        runState = .running
        runStartAt = Date()
        startBeat()
    }

    func pause() {
        guard runState == .running else { return }
        runState = .paused
        stopBeat()
    }

    func resume() {
        guard runState == .paused else { return }
        runState = .running
        runStartAt = Date().addingTimeInterval(-TimeInterval(elapsedSeconds))
        startBeat()
    }

    func stop() {
        guard runState == .running || runState == .paused else { return }
        stopBeat()
        runState = .stopped
        activeScript = nil
    }

    /// 完成一轮：推进节拍计数（真实系统点击由切换控制自定手势执行）
    func advanceRound() {
        guard runState == .running, activeScript != nil else { return }
        currentRound += 1
        if !isLoopInfinite && currentRound >= totalRounds {
            finishSuccessfully()
        }
    }

    private func finishSuccessfully() {
        stopBeat()
        runState = .completed
        NotificationService.sendCompletion(title: "脚本执行完成", body: activeScript?.name ?? "脚本已完成")
        activeScript = nil
    }

    func notifyInterrupted() {
        guard runState == .running else { return }
        stopBeat()
        runState = .stopped
        NotificationService.sendInterrupt(title: "脚本已中断", body: "请检查执行条件（三击启用/切换到控制）")
    }

    // MARK: - 节拍计时
    private func startBeat() {
        stopBeat()
        beatTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard self.runState == .running else { return }
                if self.isBackgrounded {
                    // 后台超过阈值则标记中断（FR3.6）
                    self.handleBackgroundExpiryIfNeeded()
                } else {
                    self.elapsedSeconds += 1
                }
            }
        }
    }

    private func stopBeat() {
        beatTimer?.invalidate()
        beatTimer = nil
    }

    // MARK: - 前后台监控（FR3.6：后台运行判定）
    private func observeLifecycle() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.isBackgrounded = true
                self.backgroundEnterAt = Date()
            }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.isBackgrounded = false
                self.backgroundEnterAt = nil
                if self.runState == .running {
                    // 回前台：提示执行条件可能已丢失（FR3.6）
                    self.notifyInterrupted()
                }
            }
        }
    }

    private var backgroundEnterAt: Date?

    private func handleBackgroundExpiryIfNeeded() {
        guard let enterAt = backgroundEnterAt else { return }
        if Date().timeIntervalSince(enterAt) > 30 {
            notifyInterrupted()
        }
    }

    // MARK: - 通知权限（FR4.3）
    func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - 快捷指令（FR3.1，iOS 16+）
    func registerAppShortcutsIfAvailable() {
        if #available(iOS 16.0, *) {
            AppShortcutCenter.register()
        }
    }
}
