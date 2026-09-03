// 引擎 Swift 移植单元测试（纯标准库，main.swift 顶层代码）
// 编译: swiftc CardEngine.swift main.swift -o engine_tests && ./engine_tests

var fail = 0
var pass = 0

func expect(_ cond: Bool, _ name: String) {
    if cond { pass += 1 } else { fail += 1; print("✗ " + name) }
}
func eq<T: Equatable>(_ got: T, _ want: T, _ name: String) {
    expect(got == want, name)
}

let E = Engine.self

// ---- classify ----
func c(_ arr: [Int]) -> Engine.Combo? { E.classify(arr) }
eq(c([1,0,0,0,0,0,0,0,0,0,0,0,0,0,0])?.type, "single", "classify single")
eq(c([0,2,0,0,0,0,0,0,0,0,0,0,0,0,0])?.type, "pair", "classify pair")
eq(c([0,0,3,0,0,0,0,0,0,0,0,0,0,0,0])?.type, "triple", "classify triple")
eq(c([0,0,0,4,0,0,0,0,0,0,0,0,0,0,0])?.type, "bomb", "classify bomb")
eq(c([0,0,0,0,0,0,0,0,0,0,0,0,0,1,1])?.type, "rocket", "classify rocket")
eq(c([1,1,1,1,1,0,0,0,0,0,0,0,0,0,0])?.type, "straight", "classify straight")
eq(c([0,3,1,0,0,0,0,0,0,0,0,0,0,0,0])?.type, "triple1", "classify triple1")
eq(c([0,3,2,0,0,0,0,0,0,0,0,0,0,0,0])?.type, "triple2", "classify triple2")
eq(c([2,2,2,0,0,0,0,0,0,0,0,0,0,0,0])?.type, "pairlink", "classify pairlink")
eq(c([3,3,0,0,0,0,0,0,0,0,0,0,0,0,0])?.type, "airplane", "classify airplane")
eq(c([3,3,1,1,0,0,0,0,0,0,0,0,0,0,0])?.type, "airplane1", "classify airplane1")

// ---- beats ----
let P5 = Engine.Combo(type: "pair", rank: 5, size: 2)
let P3 = Engine.Combo(type: "pair", rank: 3, size: 2)
let B8 = Engine.Combo(type: "bomb", rank: 8, size: 4)
let B10 = Engine.Combo(type: "bomb", rank: 10, size: 4)
let R = Engine.Combo(type: "rocket", rank: 14, size: 2)
let S4 = Engine.Combo(type: "straight", rank: 4, len: 5, size: 5)
let S3 = Engine.Combo(type: "straight", rank: 3, len: 5, size: 5)
expect(E.beats(P5, P3), "pair beats pair")
expect(!E.beats(P3, P5), "pair no beat")
expect(E.beats(B8, P5), "bomb beats pair")
expect(E.beats(B10, B8), "higher bomb")
expect(E.beats(R, B10), "rocket beats bomb")
expect(E.beats(S4, S3), "straight same len higher")
expect(!E.beats(S3, S4), "straight lower no")

// ---- genMoves / suggest ----
let s = E.defaultState()
E.setLandlord(s, "me")
s.myHand = E.arr0()
s.myHand[0] = 2; s.myHand[1] = 1; s.myHand[2] = 1; s.myHand[3] = 1; s.myHand[4] = 1; s.myHand[5] = 1
s.myHand[6] = 3; s.myHand[7] = 1; s.myHand[8] = 1; s.myHand[9] = 1; s.myHand[10] = 1; s.myHand[11] = 1
s.myHand[12] = 1; s.myHand[13] = 1; s.myHand[14] = 1
let moves = E.genMoves(s.myHand)
expect(moves.contains { $0.type == "single" && $0.rank == 0 }, "has single 3")
expect(moves.contains { $0.type == "pair" && $0.rank == 0 }, "has pair 3")
expect(moves.contains { $0.type == "triple" && $0.rank == 6 }, "has triple 9")
expect(moves.contains { $0.type == "straight" && $0.rank == 0 && $0.len == 5 }, "has straight 34567")
expect(moves.contains { $0.type == "rocket" }, "has rocket")
let sg = E.suggest(s)
expect(sg.kind == "lead", "suggest lead")
expect(sg.moves.count >= 1 && sg.moves.count <= 3, "suggest top3")
print("  建议1: \(sg.moves.first?.name ?? "-") | \(sg.moves.first?.reason ?? "")")

// 压牌场景
let s2 = E.defaultState()
E.setLandlord(s2, "me")
s2.myHand = E.arr0()
s2.myHand[0] = 2; s2.myHand[1] = 1; s2.myHand[2] = 1; s2.myHand[3] = 1; s2.myHand[4] = 1; s2.myHand[5] = 1
s2.myHand[6] = 3; s2.myHand[7] = 1; s2.myHand[8] = 1; s2.myHand[10] = 1; s2.myHand[11] = 2; s2.myHand[12] = 1
s2.myHand[13] = 1; s2.myHand[14] = 1
expect(E.applyPlay(s2, "up", Engine.Combo(type: "pair", rank: 9, size: 2)), "apply play up")
expect(s2.turn == "me", "turn me after up")
let sg2 = E.suggest(s2)
expect(sg2.kind == "beat", "suggest beat")
expect(sg2.moves.first?.name == "对子 A", "beat with pair A")
print("  压牌: \(sg2.target ?? "") | \(sg2.moves.first?.name ?? "") | \(sg2.moves.first?.reason ?? "")")

// 蒙特卡洛（粗略校验，不做精确计时）
let s4 = E.defaultState()
E.setLandlord(s4, "up")
s4.myHand = E.arr0()
s4.myHand[0] = 2; s4.myHand[1] = 1; s4.myHand[2] = 1; s4.myHand[3] = 1; s4.myHand[4] = 1; s4.myHand[5] = 1
s4.myHand[6] = 3; s4.myHand[7] = 1; s4.myHand[8] = 1; s4.myHand[9] = 1; s4.myHand[10] = 1; s4.myHand[11] = 1
s4.myHand[12] = 1; s4.myHand[13] = 1; s4.myHand[14] = 1
let st = E.analyzeOpponent(s4, "up", 800)
expect(st != nil, "analyze returns")
expect(st!.n == 20, "analyze n=20")
expect(st!.key14 >= 0 && st!.key14 <= 100, "analyze range")
print("  上家(地主)20张分析: 小王 \(Int(st!.key13))% 顺子 \(Int(st!.straight))% 炸弹 \(st!.bombList.count) 手")

// applyPlay 扣减
let s5 = E.defaultState()
E.setLandlord(s5, "up")
s5.myHand = E.arr0()
s5.myHand[0] = 2; s5.myHand[1] = 1; s5.myHand[2] = 1; s5.myHand[3] = 1; s5.myHand[4] = 1; s5.myHand[5] = 1
s5.myHand[6] = 3; s5.myHand[7] = 1; s5.myHand[8] = 1; s5.myHand[10] = 1; s5.myHand[11] = 1; s5.myHand[12] = 1
s5.myHand[13] = 1; s5.myHand[14] = 1
expect(E.sum(s5.myHand) == 17, "my hand 17")
expect(E.applyPlay(s5, "me", Engine.Combo(type: "pair", rank: 0, size: 2)), "play pair3")
expect(s5.myHand[0] == 0, "myHand 33 reduced")
expect(E.sum(E.poolCounts(s5)) == 37, "pool 37")
expect(E.applyPlay(s5, "up", Engine.Combo(type: "single", rank: 12, size: 1)), "up play 2")
expect(E.poolCounts(s5)[12] == 2, "pool 2 count = 2")
expect(E.remOf(s5, "up") == 19, "up rem 19")

print("\n========================")
print("PASS: \(pass)  FAIL: \(fail)")
if fail > 0 { fatalError("TESTS FAILED") }
