import SwiftUI

// MARK: - 分析页：另外两家的牌型概率（蒙特卡洛）
struct AnalysisView: View {
    @EnvironmentObject var app: AppState
    @State private var upStats: Engine.OpponentStats?
    @State private var downStats: Engine.OpponentStats?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 全局
                    VStack(alignment: .leading, spacing: 6) {
                        Text("全局局势").font(.headline).foregroundColor(Theme.gold)
                        let pool = Engine.poolCounts(app.engine)
                        Text("牌池剩 \(pool.reduce(0, +)) 张 ｜ 大王剩 \(pool[14]) ｜ 小王剩 \(pool[13]) ｜ 2 剩 \(pool[12]) ｜ A 剩 \(pool[11])")
                            .font(.caption).foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel)
                    .cornerRadius(14)

                    opponentCard("up", stats: upStats)
                    opponentCard("down", stats: downStats)

                    Text("基于剩余牌池对该玩家做 600 次蒙特卡洛采样，估算其手牌结构。")
                        .font(.caption2).foregroundColor(Theme.dim)
                }
                .padding()
            }
            .background(Theme.bg)
            .navigationTitle("对手分析")
            .onAppear { refresh() }
            .onChange(of: app.uiTick) { _ in refresh() }
        }
    }

    private func refresh() {
        upStats = Engine.analyzeOpponent(app.engine, "up", 600)
        downStats = Engine.analyzeOpponent(app.engine, "down", 600)
    }

    private func opponentCard(_ who: String, stats: Engine.OpponentStats?) -> some View {
        let role = app.engine.landlord == who ? "地主" : (app.engine.myRole == "farmer" ? "队友" : "农民")
        let roleColor = app.engine.landlord == who ? Theme.red : (app.engine.myRole == "farmer" ? Theme.blue : Theme.green)
        let rem = Engine.remOf(app.engine, who)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Engine.nameOf(who)).font(.headline).foregroundColor(.white)
                Text(role).font(.caption).fontWeight(.bold)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(roleColor.opacity(0.2)).foregroundColor(roleColor).cornerRadius(10)
                Spacer()
                Text("剩 \(rem) 张").font(.caption).foregroundColor(Theme.dim)
            }
            if let st = stats {
                bar("大王", st.key14)
                bar("小王", st.key13)
                bar("2", st.key12)
                bar("A", st.key11)
                HStack(spacing: 8) {
                    Text("顺子 \(Int(st.straight))%").font(.caption2).foregroundColor(Theme.dim)
                    Text("连对 \(Int(st.pairlink))%").font(.caption2).foregroundColor(Theme.dim)
                    Text("飞机 \(Int(st.airplane))%").font(.caption2).foregroundColor(Theme.dim)
                }
                if !st.bombList.isEmpty {
                    HStack(spacing: 6) {
                        Text("可能炸弹：").font(.caption2).foregroundColor(Theme.dim)
                        ForEach(st.bombList, id: \.rank) { b in
                            Text("\(Engine.ranks[b.rank])炸 \(Int(b.p))%")
                                .font(.caption2).fontWeight(.bold)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Theme.red.opacity(0.18)).foregroundColor(Color(red: 1, green: 0.6, blue: 0.55))
                                .cornerRadius(10)
                        }
                    }
                }
            } else {
                Text("数据不足").font(.caption).foregroundColor(Theme.dim)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .cornerRadius(14)
    }

    private func bar(_ label: String, _ pct: Double) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).foregroundColor(Theme.dim).frame(width: 40, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.gold).frame(width: geo.size.width * CGFloat(min(pct, 100) / 100))
                }
            }
            .frame(height: 8)
            Text("\(Int(pct))%").font(.caption).foregroundColor(.white).frame(width: 44, alignment: .trailing)
        }
    }
}
