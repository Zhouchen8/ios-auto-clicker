import SwiftUI

/// 首次启动安全须知（FR0.1）：10s 倒计时后确认
struct SafetyNoticeView: View {
    @EnvironmentObject var store: ScriptStore
    @State private var countdown = 10
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("使用须知")
                .font(.title2.bold())

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    bullet("本工具通过 iOS 原生「切换控制」执行系统级自动点击，不做任何注入或越狱。")
                    bullet("仅适用于本人设备、本人操作、合规用途（如辅助测试、无障碍练习）。")
                    bullet("请勿用于游戏代练、批量抢购等违反平台规则或相关法律法规的场景。")
                    bullet("连续点击可能触发系统安全提示；运行前请确认目标界面状态。")
                    bullet("后台运行受限：App 退后台超过 30 秒将自动停止并通知。")
                }
            }

            Button(action: {
                store.acceptSafety()
            }) {
                Text(countdown > 0 ? "我已阅读并同意（\(countdown)s）" : "我已阅读并同意")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(countdown > 0 ? Color.gray.opacity(0.4) : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(countdown > 0)
        }
        .padding()
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text("•")
            Text(text).font(.subheadline)
        }
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if countdown > 1 {
                countdown -= 1
            } else {
                countdown = 0
                t.invalidate()
            }
        }
    }
}
