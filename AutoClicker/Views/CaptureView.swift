import SwiftUI
import PhotosUI

/// 打点页（FR1）：覆盖层捕捉 / 手动坐标 / 截图标定，三种模式
struct CaptureView: View {
    @EnvironmentObject var store: ScriptStore

    @State private var mode: CaptureMode = .overlay
    @State private var overlayTaps: [Point] = []
    @State private var manualX = ""
    @State private var manualY = ""
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var shotImage: UIImage?
    @State private var shotTaps: [Point] = []
    @State private var savedToScript: Script?

    enum CaptureMode: String, CaseIterable, Identifiable {
        case overlay = "覆盖层捕捉"
        case manual = "手动坐标"
        case shot = "截图标定"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("打点方式", selection: $mode) {
                    ForEach(CaptureMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch mode {
                    case .overlay: overlayLayer
                    case .manual: manualForm
                    case .shot: shotLayer
                    }
                }
                .frame(maxHeight: .infinity)

                HStack {
                    Text("当前模式点位数：\(currentCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("清空") { clearAll() }
                        .foregroundStyle(.red)
                }
                .padding(.horizontal)

                Button {
                    appendToCurrentScript()
                } label: {
                    Text("保存到脚本")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(currentCount == 0)
            }
            .navigationTitle("打点")
            .sheet(item: $savedToScript) { script in
                ScriptEditView(script: script)
            }
        }
    }

    private var currentCount: Int {
        switch mode {
        case .overlay: return overlayTaps.count
        case .manual: return manualX.isEmpty && manualY.isEmpty ? 0 : 1
        case .shot: return shotTaps.count
        }
    }

    private func clearAll() {
        overlayTaps.removeAll()
        shotTaps.removeAll()
        manualX = ""
        manualY = ""
    }

    private func appendToCurrentScript() {
        var points: [Point]
        switch mode {
        case .overlay:
            points = overlayTaps
        case .manual:
            guard let x = Double(manualX), let y = Double(manualY) else { return }
            points = [Point(type: .tap, xPercent: ParamValidator.roundPercent(x), yPercent: ParamValidator.roundPercent(y))]
        case .shot:
            points = shotTaps
        }
        guard !points.isEmpty else { return }

        let script = store.createScript(named: "脚本 \(store.scripts.count + 1)")
        var updated = script
        updated.portraitPoints = points
        store.updateScript(updated)
        savedToScript = updated
        clearAll()
    }

    // MARK: 覆盖层捕捉（FR1.2）
    private var overlayLayer: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.05)
                if overlayTaps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.draw")
                        Text("点击屏幕任意位置记录相对坐标点")
                        Text("已记录 \(overlayTaps.count)/20")
                    }
                    .foregroundStyle(.secondary)
                }
                ForEach(overlayTaps) { p in
                    Circle()
                        .fill(.blue)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .position(x: geo.size.width * p.xPercent / 100,
                                  y: geo.size.height * p.yPercent / 100)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard overlayTaps.count < ParamValidator.pointLimit else { return }
                let p = Point(
                    type: .tap,
                    xPercent: ParamValidator.roundPercent(location.x / geo.size.width * 100),
                    yPercent: ParamValidator.roundPercent(location.y / geo.size.height * 100)
                )
                overlayTaps.append(p)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: 手动坐标（FR1.3）
    private var manualForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("X (%)")
                TextField("0-100", text: $manualX)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Y (%)")
                TextField("0-100", text: $manualY)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }
            Text("坐标按百分比记录，横竖屏自动适配（NFR1.3）。点击「保存到脚本」即生成 1 个点击点位。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: 截图标定（FR1.4）
    private var shotLayer: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPickerItem, matching: .images) {
                Label(shotImage == nil ? "选择目标界面截图" : "更换截图", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .onChange(of: selectedPickerItem) { _, newItem in
                loadPickerItem(newItem)
            }

            if let img = shotImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .overlay(GeometryReader { geo in
                        ZStack {
                            ForEach(shotTaps) { p in
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 20, height: 20)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .position(x: geo.size.width * p.xPercent / 100,
                                              y: geo.size.height * p.yPercent / 100)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard shotTaps.count < ParamValidator.pointLimit else { return }
                            let p = Point(
                                type: .tap,
                                xPercent: ParamValidator.roundPercent(location.x / geo.size.width * 100),
                                yPercent: ParamValidator.roundPercent(location.y / geo.size.height * 100)
                            )
                            shotTaps.append(p)
                        }
                    })
                    .frame(maxHeight: 380)
            }
            Text("在截图上点击以标定位置；同一截图最多记录 20 个点。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func loadPickerItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data, let img = UIImage(data: data) {
                    shotImage = img
                    shotTaps.removeAll()
                }
            case .failure:
                break
            }
        }
    }
}
