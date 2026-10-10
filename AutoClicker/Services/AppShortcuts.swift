import Foundation
import AppIntents

/// App Shortcuts / Siri 快捷指令（FR3.1，iOS 16+；15.x 由"快捷指令-App"手动配置退路）
@available(iOS 16.0, *)
enum AppShortcutCenter {
    static func register() {
        // App Shortcuts 由 AppShortcutsProvider 在 App 启动时自动注册（FR3.1）
    }
}

@available(iOS 16.0, *)
struct AutoClickerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartScriptIntent(),
            phrases: ["启动自动点击脚本"]
        )
        AppShortcut(
            intent: StopScriptIntent(),
            phrases: ["停止自动点击脚本"]
        )
    }
}

@available(iOS 16.0, *)
struct StartScriptIntent: AppIntent {
    static var title: LocalizedStringResource = "启动自动点击脚本"

    @Parameter(title: "脚本名称")
    var scriptName: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // 实际启动依赖 App 内选中脚本；快捷指令携带脚本名做参数透传
        return .result(value: "已接收启动请求：\(scriptName)")
    }
}

@available(iOS 16.0, *)
struct StopScriptIntent: AppIntent {
    static var title: LocalizedStringResource = "停止自动点击"

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result(value: "已停止")
    }
}
