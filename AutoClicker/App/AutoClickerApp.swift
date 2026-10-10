import SwiftUI

@main
struct AutoClickerApp: App {
    @StateObject private var store = ScriptStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: ScriptStore

    var body: some View {
        Group {
            if !store.safetyAck.accepted {
                SafetyNoticeView()
            } else {
                MainTabView()
            }
        }
        .onAppear {
            store.bootstrap()
        }
    }
}

struct MainTabView: View {
    @State private var selected: Tab = .scripts

    enum Tab: Hashable {
        case scripts, capture, console, help
    }

    var body: some View {
        TabView(selection: $selected) {
            ScriptListView()
                .tabItem { Label("脚本", systemImage: "list.bullet.rectangle") }
                .tag(Tab.scripts)

            CaptureView()
                .tabItem { Label("打点", systemImage: "hand.tap") }
                .tag(Tab.capture)

            ConsoleView()
                .tabItem { Label("运行", systemImage: "play.circle") }
                .tag(Tab.console)

            WizardView()
                .tabItem { Label("向导", systemImage: "questionmark.circle") }
                .tag(Tab.help)
        }
    }
}
