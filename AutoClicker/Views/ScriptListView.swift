import SwiftUI

/// 脚本列表（FR2 入口 / FR1.1）
struct ScriptListView: View {
    @EnvironmentObject var store: ScriptStore
    @State private var editingScript: Script?
    @State private var showDeleteConfirm: Script?

    var body: some View {
        NavigationStack {
            List {
                if store.scripts.isEmpty {
                    ContentUnavailablePlaceholder()
                } else {
                    ForEach(store.scripts) { script in
                        ScriptRow(script: script) { action in
                            switch action {
                            case .edit: editingScript = script
                            case .delete: showDeleteConfirm = script
                            }
                        }
                    }
                }
            }
            .navigationTitle("自动点击器")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let s = store.createScript()
                        editingScript = s
                    } label: {
                        Label("新建", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editingScript) { script in
                ScriptEditView(script: script)
            }
            .confirmationDialog("删除脚本？", isPresented: Binding(
                get: { showDeleteConfirm != nil },
                set: { if !$0 { showDeleteConfirm = nil } }
            ), titleVisibility: .visible) {
                if let s = showDeleteConfirm {
                    Button("删除", role: .destructive) {
                        store.deleteScript(s)
                        showDeleteConfirm = nil
                    }
                    Button("取消", role: .cancel) { showDeleteConfirm = nil }
                }
            }
        }
    }
}

enum ScriptRowAction {
    case edit, delete
}

struct ScriptRow: View {
    let script: Script
    let onAction: (ScriptRowAction) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(script.name).font(.headline)
                Text("\(script.activePoints.count) 个点位 · 间隔 \(script.params.intervalMs)ms · \(script.params.isInfinite ? "无限" : "\(script.params.repeatCount) 次")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { onAction(.edit) } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            Button { onAction(.delete) } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

struct ContentUnavailablePlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap").font(.largeTitle).foregroundStyle(.secondary)
            Text("还没有脚本").font(.headline)
            Text("点击右上角 + 新建，进入「打点」页录制第一个点位").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
