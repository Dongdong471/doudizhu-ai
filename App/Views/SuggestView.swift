import SwiftUI

// MARK: - 建议页：智能出牌方案
struct SuggestView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let s = Engine.suggest(app.engine)

                    // 主建议卡
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(s.title).font(.title3).fontWeight(.bold).foregroundColor(Theme.gold)
                            Spacer()
                            Text("轮到：\(Engine.nameOf(app.engine.turn))")
                                .font(.caption).foregroundColor(Theme.dim)
                        }
                        if !s.text.isEmpty {
                            Text(s.text).font(.subheadline).foregroundColor(.white).lineSpacing(3)
                        }
                        if let t = s.target {
                            Text("对方：\(t)")
                                .font(.caption).fontWeight(.bold)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Theme.red.opacity(0.18)).foregroundColor(Color(red: 1, green: 0.62, blue: 0.58))
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel)
                    .cornerRadius(14)

                    // 候选方案
                    if !s.moves.isEmpty {
                        Text("候选出牌").font(.headline).foregroundColor(Theme.gold)
                        ForEach(Array(s.moves.enumerated()), id: \.offset) { idx, mv in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(idx + 1). \(mv.name)")
                                        .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                                    Text(mv.reason).font(.caption2).foregroundColor(Theme.dim)
                                }
                                Spacer()
                                Button {
                                    app.manualPlay("me", combo: mv.combo)
                                } label: {
                                    Text("出").font(.subheadline).fontWeight(.bold)
                                        .padding(.horizontal, 18).padding(.vertical, 8)
                                        .background(Theme.green).foregroundColor(.white).cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(Theme.panel2)
                            .cornerRadius(12)
                        }
                    }

                    // 快捷操作
                    if app.engine.turn == "me" {
                        HStack(spacing: 8) {
                            Button {
                                app.manualPass("me")
                            } label: {
                                Text("要不起(过)").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Theme.panel2).foregroundColor(.white).cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            Button {
                                app.toggleTurn()
                            } label: {
                                Text("切换出牌人").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Theme.panel2).foregroundColor(.white).cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 手牌结构
                    VStack(alignment: .leading, spacing: 6) {
                        Text("我的手牌结构").font(.headline).foregroundColor(Theme.gold)
                        Text(Engine.describeHand(app.engine.myHand))
                            .font(.caption).foregroundColor(Theme.dim)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel)
                    .cornerRadius(14)

                    Text("提示：点「出」会自动扣减手牌并轮到下一家；识别失败时可手动补录。")
                        .font(.caption2).foregroundColor(Theme.dim)
                }
                .padding()
            }
            .background(Theme.bg)
            .navigationTitle("出牌建议")
            .onChange(of: app.uiTick) { _ in }
        }
    }
}
