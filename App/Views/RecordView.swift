import SwiftUI

// MARK: - 记牌页：剩余牌库 + 我的手牌 + 手动记录兜底
struct RecordView: View {
    @EnvironmentObject var app: AppState
    @State private var who = "up"
    @State private var mode = "auto"       // auto | pair | triple | bomb
    @State private var sel: [Int] = [Int](repeating: 0, count: 15)

    private let rankNames = Engine.ranks

    private var pool: [Int] { Engine.poolCounts(app.engine) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // 出牌人选择 + 牌型模式
                    HStack(spacing: 8) {
                        whoButton("up", "上家")
                        whoButton("me", "我")
                        whoButton("down", "下家")
                    }
                    HStack(spacing: 8) {
                        modeButton("auto", "自由")
                        modeButton("pair", "对子")
                        modeButton("triple", "三张")
                        modeButton("bomb", "炸弹")
                    }

                    // 点数键盘（点击计入待确认）
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 7) {
                        ForEach(0..<15, id: \.self) { r in
                            Button { tapRank(r) } label: {
                                VStack(spacing: 2) {
                                    Text(rankNames[r])
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(keyColor(r))
                                    Text("剩\(pool[r])")
                                        .font(.system(size: 10))
                                        .foregroundColor(pool[r] <= 0 ? Theme.dim : Theme.dim)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(sel[r] > 0 ? Theme.green.opacity(0.28) : Theme.panel2)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(sel[r] > 0 ? Theme.green : Theme.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 待确认预览
                    HStack {
                        Text("待确认：[\(Engine.nameOf(who))] " + preview)
                            .font(.caption)
                            .foregroundColor(Theme.dim)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(10)
                    .background(Theme.panel2)
                    .cornerRadius(10)

                    HStack(spacing: 8) {
                        Button { confirm() } label: {
                            Text("✓ 确认出牌").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(Theme.green).foregroundColor(.white).cornerRadius(11)
                        }
                        .buttonStyle(.plain)
                        Button { app.manualPass(who) } label: {
                            Text("要不起(过)").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(Theme.panel2).foregroundColor(.white).cornerRadius(11)
                        }
                        .buttonStyle(.plain)
                        Button { sel = [Int](repeating: 0, count: 15) } label: {
                            Text("清空").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(Theme.panel2).foregroundColor(.white).cornerRadius(11)
                        }
                        .buttonStyle(.plain)
                    }

                    // 剩余牌库（只读）
                    panelTitle("剩余牌库（外面还有几张）")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 7) {
                        ForEach(0..<15, id: \.self) { r in
                            VStack(spacing: 2) {
                                Text(rankNames[r]).font(.system(size: 14, weight: .bold)).foregroundColor(keyColor(r))
                                Text("剩\(pool[r])").font(.system(size: 10)).foregroundColor(pool[r] <= 0 ? Theme.dim : .white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(pool[r] <= 0 ? Theme.panel2.opacity(0.5) : Theme.panel2)
                            .cornerRadius(10)
                        }
                    }

                    // 我的手牌
                    panelTitle("我的手牌（\(app.engine.myHand.reduce(0, +))张）")
                    if app.engine.myHand.reduce(0, +) == 0 {
                        Text("尚未录入，请在「设置」中录入或开启自动识别")
                            .font(.caption).foregroundColor(Theme.dim).padding(.vertical, 6)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 7) {
                            ForEach(0..<15, id: \.self) { r in
                                if app.engine.myHand[r] > 0 {
                                    VStack(spacing: 2) {
                                        Text(rankNames[r]).font(.system(size: 14, weight: .bold)).foregroundColor(keyColor(r))
                                        Text("×\(app.engine.myHand[r])").font(.system(size: 10)).foregroundColor(Theme.dim)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(Theme.panel2)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }

                    // 流水
                    panelTitle("出牌流水")
                    if app.logLines.isEmpty {
                        Text("暂无记录").font(.caption).foregroundColor(Theme.dim)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(app.logLines.suffix(30).enumerated()), id: \.offset) { _, line in
                                Text("▸ \(line)").font(.caption2).foregroundColor(Theme.dim)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.bg)
            .navigationTitle("记牌")
        }
    }

    // MARK: helpers
    private var preview: String {
        let combo = Engine.classify(sel)
        if let c = combo { return Engine.comboName(c) }
        let parts = (0..<15).filter { sel[$0] > 0 }.map { "\(rankNames[$0])×\(sel[$0])" }
        return parts.isEmpty ? "尚未选牌" : parts.joined(separator: " ")
    }

    private func whoButton(_ w: String, _ label: String) -> some View {
        Button { who = w } label: {
            Text(label).font(.subheadline).fontWeight(.bold)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(who == w ? Theme.gold.opacity(0.22) : Theme.panel2)
                .foregroundColor(who == w ? Theme.gold : Theme.dim)
                .cornerRadius(11)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(who == w ? Theme.gold : Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
    private func modeButton(_ m: String, _ label: String) -> some View {
        Button { mode = m; sel = [Int](repeating: 0, count: 15) } label: {
            Text(label).font(.caption).padding(.horizontal, 10).padding(.vertical, 6)
                .background(mode == m ? Theme.green.opacity(0.22) : Theme.panel2)
                .foregroundColor(mode == m ? Theme.green : Theme.dim)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
    private func tapRank(_ r: Int) {
        let avail = (who == "me") ? app.engine.myHand[r] : pool[r]
        guard avail > 0 else { return }
        switch mode {
        case "pair": sel[r] = sel[r] >= 2 ? 0 : min(2, avail)
        case "triple": sel[r] = sel[r] >= 3 ? 0 : min(3, avail)
        case "bomb": sel[r] = sel[r] >= 4 ? 0 : min(4, avail)
        default: sel[r] = (sel[r] >= avail) ? 0 : sel[r] + 1
        }
    }
    private func confirm() {
        guard let combo = Engine.classify(sel), combo.type != "other" else { return }
        app.manualPlay(who, combo: combo)
        sel = [Int](repeating: 0, count: 15)
    }
    private func keyColor(_ r: Int) -> Color {
        if r >= 11 { return Theme.gold }
        return (r == 1 || r == 3) ? Theme.red : .white
    }
    private func panelTitle(_ t: String) -> some View {
        Text(t).font(.headline).foregroundColor(Theme.gold).padding(.top, 4)
    }
}
