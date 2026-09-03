import SwiftUI

// MARK: - 设置页：角色/地主、手牌编辑、新开一局
struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var editHand: [Int] = [Int](repeating: 0, count: 15)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // 地主是谁
                    VStack(alignment: .leading, spacing: 8) {
                        Text("本局地主").font(.headline).foregroundColor(Theme.gold)
                        HStack(spacing: 8) {
                            landlordButton("me", "我")
                            landlordButton("up", "上家")
                            landlordButton("down", "下家")
                        }
                        Text("我的角色：\(app.engine.myRole == "landlord" ? "地主" : "农民")")
                            .font(.caption).foregroundColor(Theme.dim)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel)
                    .cornerRadius(14)

                    // 手牌编辑
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("手牌编辑（共 \(editHand.reduce(0, +)) 张）").font(.headline).foregroundColor(Theme.gold)
                            Spacer()
                            Button("应用") { app.manualSetHand(editHand) }
                                .font(.subheadline).fontWeight(.bold)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(Theme.green).foregroundColor(.white).cornerRadius(9)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 7) {
                            ForEach(0..<15, id: \.self) { r in
                                HStack {
                                    Button { if editHand[r] > 0 { editHand[r] -= 1 } } label: {
                                        Image(systemName: "minus.circle").foregroundColor(Theme.dim)
                                    }
                                    .buttonStyle(.plain)
                                    VStack(spacing: 1) {
                                        Text(Engine.ranks[r]).font(.system(size: 13, weight: .bold)).foregroundColor(keyColor(r))
                                        Text("×\(editHand[r])").font(.system(size: 10)).foregroundColor(Theme.dim)
                                    }
                                    Button { if editHand[r] < Engine.full[r] { editHand[r] += 1 } } label: {
                                        Image(systemName: "plus.circle").foregroundColor(Theme.gold)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(Theme.panel2)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel)
                    .cornerRadius(14)

                    // 新开一局 / 清记录
                    HStack(spacing: 8) {
                        Button { app.newGame() } label: {
                            Text("🔄 新开一局").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Theme.blue).foregroundColor(.white).cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }

                    // 说明
                    VStack(alignment: .leading, spacing: 6) {
                        Text("使用说明").font(.headline).foregroundColor(Theme.gold)
                        Text("1. 控制中心 → 长按录屏 → 选「斗地主AI记牌」开始录制。\n2. App 会自动识别手牌与桌面出牌并更新分析。\n3. 识别不准时，可在「记牌」页手动补录，或在本页校准手牌。\n4. 不同斗地主 App 牌面布局不同，OCR 区域可在源码中微调。")
                            .font(.caption2).foregroundColor(Theme.dim).lineSpacing(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel)
                    .cornerRadius(14)
                }
                .padding()
            }
            .background(Theme.bg)
            .navigationTitle("设置")
            .onAppear {
                editHand = app.engine.myHand
            }
            .onChange(of: app.uiTick) { _ in
                editHand = app.engine.myHand
            }
        }
    }

    private func landlordButton(_ w: String, _ label: String) -> some View {
        Button { app.setLandlord(w) } label: {
            Text(label).font(.subheadline).fontWeight(.bold)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(app.engine.landlord == w ? Theme.gold.opacity(0.22) : Theme.panel2)
                .foregroundColor(app.engine.landlord == w ? Theme.gold : Theme.dim)
                .cornerRadius(11)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(app.engine.landlord == w ? Theme.gold : Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func keyColor(_ r: Int) -> Color {
        if r >= 11 { return Theme.gold }
        return (r == 1 || r == 3) ? Theme.red : .white
    }
}
