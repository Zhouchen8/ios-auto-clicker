import SwiftUI

/// 运行控制台（FR3/FR4）：选择脚本、启动/暂停/停止、节拍进度、三击引导
struct ConsoleView: View {
    @EnvironmentObject var store: ScriptStore
    @State private var selectedScriptId: UUID?

    private var selectedScript: Script? {
        store.scripts.first { $0.id == selectedScriptId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("选择脚本") {
                    if store.scripts.isEmpty {
                        Text("暂无脚本，请先到「打点」页创建").foregroundStyle(.secondary)
                    } else {
                        Picker("脚本", selection: $selectedScriptId) {
                            ForEach(store.scripts) { s in
                                Text(s.name).tag(Optional(s.id))
                            }
                        }
                    }
                }

                if let script = selectedScript {
                    Section("运行状态") {
                        HStack {
                            Text("状态")
                            Spacer()
                            Text(store.runState.displayName)
                                .foregroundStyle(store.runState == .running ? .green : .secondary)
                        }
                        HStack {
                            Text("已执行轮次")
                            Spacer()
                            Text("\(store.currentRound)/\(script.params.isInfinite ? "∞" : "\(script.params.repeatCount)")")
                        }
                        HStack {
                            Text("已运行时长")
                            Spacer()
                            Text(timeString(store.elapsedSeconds))
                        }
                        if let s = store.activeScript {
                            HStack {
                                Text("当前脚本")
                                Spacer()
                                Text(s.name).foregroundStyle(.secondary)
                            }
                        }
                        if !UIAccessibility.isSwitchControlRunning {
                            Label("切换控制未开启：真实点击不会执行，请先在「向导」页配置", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Section("控制") {
                        HStack(spacing: 12) {
                            if store.runState == .running || store.runState == .paused {
                                Button(store.runState == .paused ? "继续" : "暂停") {
                                    if store.runState == .paused { store.resume() } else { store.pause() }
                                }
                                .buttonStyle(.borderedProminent)

                                Button("停止", role: .destructive) {
                                    store.stop()
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("启动") {
                                    store.start(script: script)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!ParamValidator.validate(script).isEmpty)
                            }
                        }
                    }
                }

                Section("执行说明（FR3.2）") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("本工具不注入系统，真实点击由 iOS 原生「切换控制」的自定手势执行。")
                        Text("1. 在「向导」页完成五步配置。")
                        Text("2. 回到目标 App，连按三次侧边按钮启用切换控制。")
                        Text("3. 切回本页点击「启动」，控制台按脚本节拍计数。")
                        Text("4. 再次连按三次侧边按钮可停止，或在本页点「停止」。")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("运行控制台")
            .onAppear {
                if selectedScriptId == nil { selectedScriptId = store.scripts.first?.id }
            }
            .onDisappear {
                if store.runState == .paused {
                    store.stop()
                }
            }
        }
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}
