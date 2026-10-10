import SwiftUI

/// 五步配置向导（FR0.2）+ 帮助信息
struct WizardView: View {
    @EnvironmentObject var store: ScriptStore
    @State private var progress: GuideProgress?
    @State private var selectedScriptId: UUID?

    private var selectedScript: Script? {
        store.scripts.first { $0.id == selectedScriptId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("选择目标脚本") {
                    if store.scripts.isEmpty {
                        Text("暂无脚本，请先创建").foregroundStyle(.secondary)
                    } else {
                        Picker("脚本", selection: $selectedScriptId) {
                            ForEach(store.scripts) { s in
                                Text(s.name).tag(Optional(s.id))
                            }
                        }
                        .onChange(of: selectedScriptId) { newId in
                            if let id = newId {
                                progress = store.scripts.first { $0.id == id }.flatMap { s in
                                    GuideProgress(scriptId: s.id)
                                }
                            }
                        }
                    }
                }

                if let p = progress {
                    Section("五步配置向导（\(stepsDone(p))/5）") {
                        stepRow(index: 0, text: "确认点位与参数", done: p.steps[0])
                        stepRow(index: 1, text: "打开「设置 → 辅助功能 → 切换控制」", done: p.steps[1])
                        stepRow(index: 2, text: "在切换控制中「录制自定手势」", done: p.steps[2])
                        stepRow(index: 3, text: "配置扫描方式与循环次数（建议循环开启）", done: p.steps[3])
                        stepRow(index: 4, text: "三击侧边按钮启用，切回目标界面运行", done: p.steps[4])

                        Button(stepsDone(p) == 5 ? "重新开始" : "标记完成") {
                            toggleStep()
                        }
                    }
                }

                Section("常见问题") {
                    DisclosureGroup("为什么不能直接在 App 内模拟点击？") {
                        Text("iOS 沙盒与 App Store 审核禁止第三方模拟系统输入，无法像安卓那样无障碍全局点击。本工具改用系统原生「切换控制」执行，免越狱、合规。")
                            .font(.caption)
                    }
                    DisclosureGroup("支持哪些 iOS 版本？") {
                        Text("iOS 16+ 可安装使用；原生辅助功能路径 iOS 16+，代理模式 iOS 17+（需签名 IPA）。App 内快捷指令能力 iOS 16+。")
                            .font(.caption)
                    }
                    DisclosureGroup("签名方式有哪些？") {
                        Text("个人免费签名 7 天需重签；开发者签名 $99/年 1 年有效。代理模式独立分发、不进 App Store。")
                            .font(.caption)
                    }
                    DisclosureGroup("运行到一半停了？") {
                        Text("后台运行受限，退后台超 30 秒自动停止并通知；请保持前台或按系统提示处理。")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("配置向导")
            .onAppear {
                if selectedScriptId == nil { selectedScriptId = store.scripts.first?.id }
                refreshProgress()
            }
            .onChange(of: store.scripts) { _ in refreshProgress() }
        }
    }

    private func refreshProgress() {
        guard let id = selectedScriptId else { return }
        progress = GuideProgress(scriptId: id)
    }

    private func stepsDone(_ p: GuideProgress) -> Int {
        p.steps.filter { $0 }.count
    }

    private func stepRow(index: Int, text: String, done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            Text(text)
                .strikethrough(done)
                .foregroundStyle(done ? .secondary : .primary)
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleStep(index) }
    }

    private func toggleStep(_ index: Int? = nil) {
        guard var p = progress else { return }
        if let index {
            p.steps[index].toggle()
        } else if stepsDone(p) < 5 {
            p.steps = [true, true, true, true, true]
        } else {
            p.steps = [false, false, false, false, false]
        }
        p.updatedAt = Date()
        progress = p
    }
}
