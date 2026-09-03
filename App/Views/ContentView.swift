import SwiftUI
import UIKit
import ReplayKit

// MARK: - 主题色
enum Theme {
    static let bg = Color(red: 0.06, green: 0.07, blue: 0.125)
    static let panel = Color(red: 0.094, green: 0.114, blue: 0.20)
    static let panel2 = Color(red: 0.122, green: 0.145, blue: 0.25)
    static let gold = Color(red: 0.95, green: 0.78, blue: 0.06)
    static let red = Color(red: 0.91, green: 0.30, blue: 0.25)
    static let green = Color(red: 0.18, green: 0.80, blue: 0.46)
    static let blue = Color(red: 0.29, green: 0.64, blue: 1.0)
    static let dim = Color(red: 0.55, green: 0.58, blue: 0.70)
    static let line = Color(red: 0.16, green: 0.19, blue: 0.32)
}

// MARK: - 系统"屏幕录制目标选择器"（点击后在系统弹窗里选择本 App 扩展）
struct BroadcastPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPBroadcastPickerView {
        let v = RPBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        v.showsMicrophoneButton = false
        if let url = Bundle.main.url(forResource: "DoudizhuAIBroadcast",
                                     withExtension: "appex", subdirectory: "PlugIns"),
           let bundle = Bundle(url: url) {
            v.preferredExtension = bundle.bundleIdentifier
        }
        return v
    }
    func updateUIView(_ uiView: RPBroadcastPickerView, context: Context) {}
}

// MARK: - 主界面（Tab 容器）
struct ContentView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView {
            CaptureView().tabItem { Label("识别", systemImage: "record.circle") }
            RecordView().tabItem { Label("记牌", systemImage: "rectangle.grid.2x2") }
            AnalysisView().tabItem { Label("分析", systemImage: "chart.bar.xaxis") }
            SuggestView().tabItem { Label("建议", systemImage: "lightbulb") }
            SettingsView().tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }
}

// MARK: - 识别页：启动屏幕录制 + 实时画面 + OCR 日志
struct CaptureView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 状态卡
                    VStack(alignment: .leading, spacing: 8) {
                        Text("屏幕识别").font(.headline).foregroundColor(Theme.gold)
                        HStack {
                            Circle().fill(app.captureStatus.contains("已连接") ? Theme.green : Theme.red).frame(width: 8, height: 8)
                            Text(app.captureStatus).font(.subheadline).foregroundColor(.white)
                            Spacer()
                            Text("帧 \(app.frameCount)").font(.caption).foregroundColor(Theme.dim)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel)
                    .cornerRadius(14)

                    // 开始按钮
                    VStack(spacing: 10) {
                        HStack {
                            BroadcastPickerView().frame(width: 64, height: 64)
                            Text("点击左侧按钮 → 系统弹窗里选「斗地主AI记牌」→ 开始广播")
                                .font(.caption).foregroundColor(Theme.dim)
                        }
                        Text("完整操作：控制中心 → 长按录屏 → 选择「斗地主AI记牌」→ 开始录制。\n随后回到游戏 App，画面会实时推送到本工具识别。")
                            .font(.caption2)
                            .foregroundColor(Theme.dim)
                            .lineSpacing(3)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel)
                    .cornerRadius(14)

                    // 实时画面
                    if let img = app.latestFrame {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    } else {
                        VStack {
                            Image(systemName: "video.slash")
                            Text("尚无画面，请开始屏幕录制").font(.caption).foregroundColor(Theme.dim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .background(Theme.panel)
                        .cornerRadius(12)
                    }

                    // 自动识别开关
                    Toggle(isOn: $app.autoRecognizeEnabled) {
                        VStack(alignment: .leading) {
                            Text("自动识别并记牌").font(.subheadline).foregroundColor(.white)
                            Text("关闭后仅手动记录").font(.caption2).foregroundColor(Theme.dim)
                        }
                    }
                    .tint(Theme.green)
                    .padding()
                    .background(Theme.panel)
                    .cornerRadius(14)

                    // OCR 调试日志
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OCR 识别（调试）").font(.subheadline).foregroundColor(Theme.gold)
                        Text(app.lastRawOCR.isEmpty ? "暂无识别文本" : app.lastRawOCR.joined(separator: "  "))
                            .font(.caption2)
                            .foregroundColor(Theme.dim)
                            .lineLimit(6)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel)
                    .cornerRadius(14)
                }
                .padding()
            }
            .background(Theme.bg)
            .navigationTitle("屏幕识别")
        }
    }
}
