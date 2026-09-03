/// 斗地主记牌 · 对手牌型分析 · 出牌建议 —— Swift 核心引擎（纯 Swift 标准库，无任何系统框架依赖）
/// 由 PWA 版 engine.js 移植，逻辑保持一致，可在 macOS 上独立编译与单元测试。

enum Engine {

    // MARK: - 常量
    static let ranks = ["3","4","5","6","7","8","9","10","J","Q","K","A","2","小王","大王"]
    static let n = ranks.count                      // 15
    static let full = [4,4,4,4,4,4,4,4,4,4,4,4,4,1,1]
    static let order = ["me","down","up"]

    // MARK: - 牌型描述
    struct Combo: Equatable {
        var type: String
        var rank: Int
        var len: Int = 0
        var size: Int = 0
        var wings: [Int] = []
    }

    // MARK: - 状态
    final class GameState {
        var myRole = "landlord"                     // landlord | farmer
        var landlord = "me"                         // me | up | down
        var initCounts: [String:Int] = ["me":17, "up":17, "down":17]
        var myHand = [Int](repeating: 0, count: 15) // 我当前手牌
        var played = [Int](repeating: 0, count: 15) // 全场已出（含我的）
        var pPlayed: [String:[Int]] = [
            "me": [Int](repeating: 0, count: 15),
            "up": [Int](repeating: 0, count: 15),
            "down": [Int](repeating: 0, count: 15)
        ]
        var pPass: [String:Int] = ["me":0, "up":0, "down":0]
        var log: [String] = []                      // 人类可读日志
        var turn = "me"
        var lastPlayWho: String? = nil
        var lastPlayCombo: Combo? = nil

        func copy() -> GameState {
            let s = GameState()
            s.myRole = myRole; s.landlord = landlord
            s.initCounts = initCounts
            s.myHand = myHand; s.played = played
            s.pPlayed = pPlayed.mapValues { $0 }
            s.pPass = pPass
            s.log = log; s.turn = turn
            s.lastPlayWho = lastPlayWho
            s.lastPlayCombo = lastPlayCombo
            return s
        }
    }

    static func arr0() -> [Int] { return [Int](repeating: 0, count: n) }
    static func sum(_ a: [Int]) -> Int { return a.reduce(0, +) }
    static func nameOf(_ who: String) -> String {
        return who == "me" ? "我" : (who == "up" ? "上家" : "下家")
    }
    static func nextOf(_ who: String) -> String {
        return order[(order.firstIndex(of: who)! + 1) % 3]
    }
    static func prevOf(_ who: String) -> String {
        return order[(order.firstIndex(of: who)! + 2) % 3]
    }

    // MARK: - 状态操作
    static func defaultState() -> GameState { return GameState() }

    static func setLandlord(_ s: GameState, _ who: String) {
        s.landlord = who
        s.myRole = (who == "me") ? "landlord" : "farmer"
        s.initCounts["me"] = (who == "me") ? 20 : 17
        s.initCounts["up"] = (who == "up") ? 20 : 17
        s.initCounts["down"] = (who == "down") ? 20 : 17
        s.turn = who
    }

    static func remOf(_ s: GameState, _ who: String) -> Int {
        return s.initCounts[who]! - sum(s.pPlayed[who]!)
    }

    /// 剩余(对手之间)牌池
    static func poolCounts(_ s: GameState) -> [Int] {
        var p = arr0()
        for r in 0..<n { p[r] = full[r] - s.played[r] - s.myHand[r] }
        return p
    }
    static func expandPool(_ s: GameState) -> [Int] {
        let pc = poolCounts(s)
        var arr: [Int] = []
        for r in 0..<n { for _ in 0..<pc[r] { arr.append(r) } }
        return arr
    }

    // MARK: - 牌型识别
    static func classify(_ counts: [Int]) -> Combo? {
        var nz: [Int] = []
        for r in 0..<n where counts[r] > 0 { nz.append(r) }
        if nz.isEmpty { return nil }
        let total = nz.reduce(0) { $0 + counts[$1] }

        if nz.count == 1 {
            let r0 = nz[0], c = counts[r0]
            if c == 1 { return Combo(type: "single", rank: r0, size: 1) }
            if c == 2 { return Combo(type: "pair", rank: r0, size: 2) }
            if c == 3 { return Combo(type: "triple", rank: r0, size: 3) }
            if c == 4 { return Combo(type: "bomb", rank: r0, size: 4) }
            return nil
        }
        // 王炸
        if nz.count == 2 && counts[13] == 1 && counts[14] == 1 && total == 2 {
            return Combo(type: "rocket", rank: 14, size: 2)
        }
        let isCons = { () -> Bool in
            for i in 1..<nz.count where nz[i] != nz[i-1] + 1 { return false }
            return true
        }
        let allEq = { (v: Int) -> Bool in nz.allSatisfy { counts[$0] == v } }

        if nz.count >= 5 && allEq(1) && isCons() && nz.last! <= 11 {
            return Combo(type: "straight", rank: nz[0], len: nz.count, size: total)
        }
        if nz.count >= 3 && allEq(2) && isCons() && nz.last! <= 11 {
            return Combo(type: "pairlink", rank: nz[0], len: nz.count, size: total)
        }
        if nz.count >= 2 && allEq(3) && isCons() && nz.last! <= 11 {
            return Combo(type: "airplane", rank: nz[0], len: nz.count, size: total)
        }

        var t = -1, s1 = -1, s2 = -1
        for rr in nz {
            if counts[rr] == 3 { t = rr }
            else if counts[rr] == 1 { s1 = rr }
            else if counts[rr] == 2 { s2 = rr }
        }
        if total == 4 && t >= 0 && s1 >= 0 { return Combo(type: "triple1", rank: t, size: 4, wings: [s1]) }
        if total == 5 && t >= 0 && s2 >= 0 { return Combo(type: "triple2", rank: t, size: 5, wings: [s2]) }

        let tris = nz.filter { counts[$0] == 3 }
        if tris.count >= 2 && tris.last! <= 11 {
            var consT = true
            for i in 1..<tris.count where tris[i] != tris[i-1] + 1 { consT = false; break }
            if consT {
                let wings = nz.filter { counts[$0] != 3 }
                let wingCount = wings.reduce(0) { $0 + counts[$1] }
                if wingCount == tris.count {
                    return Combo(type: "airplane1", rank: tris[0], len: tris.count, size: total, wings: wings)
                }
                let allWingPairs = !wings.isEmpty && wings.allSatisfy { counts[$0] == 2 }
                if wingCount == 2 * tris.count && allWingPairs {
                    return Combo(type: "airplane2", rank: tris[0], len: tris.count, size: total, wings: wings)
                }
            }
        }

        if let b = nz.first(where: { counts[$0] == 4 }), b < 13 {
            let rest = nz.filter { $0 != b }
            let restCnt = rest.reduce(0) { $0 + counts[$1] }
            if restCnt == 2 { return Combo(type: "four2", rank: b, size: 6, wings: rest) }
            if restCnt == 4 && rest.count == 2 && counts[rest[0]] == 2 && counts[rest[1]] == 2 {
                return Combo(type: "four22", rank: b, size: 8, wings: rest)
            }
        }
        return Combo(type: "other", rank: nz[0], size: total)
    }

    // MARK: - combo -> rank->count
    static func comboCounts(_ c: Combo) -> [Int] {
        var out = arr0()
        func set(_ r: Int, _ k: Int) { out[r] += k }
        switch c.type {
        case "single": set(c.rank, 1)
        case "pair": set(c.rank, 2)
        case "triple": set(c.rank, 3)
        case "bomb": set(c.rank, 4)
        case "rocket": set(13, 1); set(14, 1)
        case "straight": for r in c.rank..<(c.rank + c.len) { set(r, 1) }
        case "pairlink": for r in c.rank..<(c.rank + c.len) { set(r, 2) }
        case "airplane": for r in c.rank..<(c.rank + c.len) { set(r, 3) }
        case "triple1": set(c.rank, 3); for w in c.wings { set(w, 1) }
        case "triple2": set(c.rank, 3); for w in c.wings { set(w, 2) }
        case "airplane1": for r in c.rank..<(c.rank + c.len) { set(r, 3) }; for w in c.wings { set(w, 1) }
        case "airplane2": for r in c.rank..<(c.rank + c.len) { set(r, 3) }; for w in c.wings { set(w, 2) }
        case "four2": set(c.rank, 4); for w in c.wings { set(w, 1) }
        case "four22": set(c.rank, 4); for w in c.wings { set(w, 2) }
        default: return arr0()
        }
        return out
    }

    // MARK: - 牌型比较
    static func beats(_ a: Combo, _ b: Combo?) -> Bool {
        guard let b = b else { return true }
        if a.type == "rocket" { return true }
        if b.type == "rocket" { return false }
        if a.type == "bomb" { return b.type != "bomb" ? true : a.rank > b.rank }
        if b.type == "bomb" { return false }
        if a.type != b.type { return false }
        switch a.type {
        case "single", "pair", "triple": return a.rank > b.rank
        case "straight", "pairlink", "airplane": return a.len == b.len && a.rank > b.rank
        case "triple1", "triple2", "four2", "four22": return a.rank > b.rank
        default: return false
        }
    }

    // MARK: - 出牌候选生成
    static func genMoves(_ hand: [Int]) -> [Combo] {
        var moves: [Combo] = []
        func push(_ c: Combo?) { if let c = c { moves.append(c) } }
        for r in 0..<n {
            if hand[r] >= 1 { push(Combo(type: "single", rank: r, size: 1)) }
            if hand[r] >= 2 { push(Combo(type: "pair", rank: r, size: 2)) }
            if hand[r] >= 3 { push(Combo(type: "triple", rank: r, size: 3)) }
            if hand[r] >= 4 && r < 13 { push(Combo(type: "bomb", rank: r, size: 4)) }
        }
        if hand[13] >= 1 && hand[14] >= 1 { push(Combo(type: "rocket", rank: 14, size: 2)) }
        for len in 5...12 {
            for s in 0...(12 - len) {
                var ok = true
                for r in s..<(s + len) where hand[r] < 1 { ok = false; break }
                if ok { push(Combo(type: "straight", rank: s, len: len, size: len)) }
            }
        }
        for len in 3...7 {
            for s in 0...(12 - len) {
                var ok = true
                for r in s..<(s + len) where hand[r] < 2 { ok = false; break }
                if ok { push(Combo(type: "pairlink", rank: s, len: len, size: len * 2)) }
            }
        }
        for len in 2...4 {
            for s in 0...(12 - len) {
                var ok = true
                for r in s..<(s + len) where hand[r] < 3 { ok = false; break }
                if ok { push(Combo(type: "airplane", rank: s, len: len, size: len * 3)) }
            }
        }
        for t in 0..<13 where hand[t] >= 3 {
            for s in 0..<n where s != t && hand[s] >= 1 { push(Combo(type: "triple1", rank: t, size: 4, wings: [s])) }
            for s in 0..<13 where s != t && hand[s] >= 2 { push(Combo(type: "triple2", rank: t, size: 5, wings: [s])) }
        }
        for b in 0..<13 where hand[b] >= 4 {
            for i in 0..<n where i != b && hand[i] >= 1 {
                for j in (i+1)..<n where j != b && hand[j] >= 1 {
                    push(Combo(type: "four2", rank: b, size: 6, wings: [i, j]))
                }
            }
            for i in 0..<13 where i != b && hand[i] >= 2 {
                for j in (i+1)..<13 where j != b && hand[j] >= 2 {
                    push(Combo(type: "four22", rank: b, size: 8, wings: [i, j]))
                }
            }
        }
        return moves
    }

    static func subtract(_ hand: [Int], _ combo: Combo) -> [Int] {
        var out = hand
        let cc = comboCounts(combo)
        for r in 0..<n { out[r] = max(0, out[r] - cc[r]) }
        return out
    }

    // MARK: - 手牌结构启发
    static func structureUnits(_ hand: [Int]) -> Int {
        var h = hand
        var units = 0
        // 顺子
        var changed = true
        while changed {
            changed = false
            for len in stride(from: 12, through: 5, by: -1) {
                for s in 0...(12 - len) {
                    var ok = true
                    for r in s..<(s + len) where h[r] < 1 { ok = false; break }
                    if ok { for r in s..<(s + len) { h[r] -= 1 }; units += 1; changed = true; break }
                }
                if changed { break }
            }
        }
        // 连对
        changed = true
        while changed {
            changed = false
            for len in stride(from: 7, through: 3, by: -1) {
                for s in 0...(12 - len) {
                    var ok = true
                    for r in s..<(s + len) where h[r] < 2 { ok = false; break }
                    if ok { for r in s..<(s + len) { h[r] -= 2 }; units += 1; changed = true; break }
                }
                if changed { break }
            }
        }
        // 飞机
        changed = true
        while changed {
            changed = false
            for len in stride(from: 4, through: 2, by: -1) {
                for s in 0...(12 - len) {
                    var ok = true
                    for r in s..<(s + len) where h[r] < 3 { ok = false; break }
                    if ok { for r in s..<(s + len) { h[r] -= 3 }; units += 1; changed = true; break }
                }
                if changed { break }
            }
        }
        for r in 0..<n {
            var c = h[r]
            while c >= 3 { units += 1; c -= 3 }
            while c >= 2 { units += 1; c -= 2 }
            while c >= 1 { units += 1; c -= 1 }
        }
        return units
    }

    static func weight(_ r: Int) -> Int { return r <= 12 ? r + 1 : (r == 13 ? 14 : 15) }
    static func avgCost(_ c: Combo) -> Double {
        let cc = comboCounts(c)
        var w = 0, cnt = 0
        for r in 0..<n { w += weight(r) * cc[r]; cnt += cc[r] }
        return cnt > 0 ? Double(w) / Double(cnt) : 0
    }
    static func isControl(_ c: Combo) -> Bool {
        let cc = comboCounts(c)
        return cc[12] > 0 || cc[13] > 0 || cc[14] > 0
    }

    static func scoreLead(_ move: Combo, _ hand: [Int], _ s: GameState) -> Double {
        let after = subtract(hand, move)
        let totalAfter = sum(after)
        let finish = totalAfter == 0 ? 100000.0 : (totalAfter <= 2 ? 40000.0 : 0)
        let cost = avgCost(move)
        let uGain = Double(structureUnits(hand) - structureUnits(after))
        var score = finish + uGain * 40 - cost * 2
        if move.type == "bomb" || move.type == "rocket" { score -= 120 }
        if isControl(move) { score -= 12 }
        if s.myRole == "farmer" && move.type == "single" && move.rank <= 7 { score += 6 }
        return score
    }

    static func scoreBeat(_ move: Combo, _ target: Combo, _ hand: [Int], _ s: GameState) -> Double {
        let after = subtract(hand, move)
        let totalAfter = sum(after)
        let finish = totalAfter == 0 ? 100000.0 : (totalAfter <= 2 ? 40000.0 : 0)
        let cost = avgCost(move)
        var score = finish - cost * 3
        if move.type == "bomb" { score -= 220 }
        if move.type == "rocket" { score -= 320 }
        if isControl(move) { score -= 12 }
        score += Double(structureUnits(hand) - structureUnits(after)) * 20
        return score
    }

    // MARK: - 对手分析（蒙特卡洛）
    struct OpponentStats {
        var n: Int
        var key11 = 0.0, key12 = 0.0, key13 = 0.0, key14 = 0.0
        var straight = 0.0, pairlink = 0.0, airplane = 0.0
        var bigPower = 0.0
        var bombList: [(rank: Int, p: Double)] = []
    }

    static func analyzeOpponent(_ s: GameState, _ who: String, _ samples: Int = 600) -> OpponentStats? {
        var pool = expandPool(s)
        let p = pool.count
        let rem = remOf(s, who)
        if p <= 0 || rem <= 0 || rem > p { return nil }

        var st = OpponentStats(n: rem)
        var cnt = arr0()
        var bombs: [Int:Int] = [:]

        for _ in 0..<samples {
            // 部分洗牌取前 rem
            if p > rem {
                for i in stride(from: p - 1, through: p - rem, by: -1) {
                    let j = Int.random(in: 0...i)
                    pool.swapAt(i, j)
                }
            }
            for r in 0..<n { cnt[r] = 0 }
            for k in (p - rem)..<p { cnt[pool[k]] += 1 }
            for kk in 0...12 { st.bigPower += Double(cnt[kk] * weight(kk)) }
            st.bigPower += Double(cnt[13] * 16 + cnt[14] * 18)
            if cnt[11] > 0 { st.key11 += 1 }
            if cnt[12] > 0 { st.key12 += 1 }
            if cnt[13] > 0 { st.key13 += 1 }
            if cnt[14] > 0 { st.key14 += 1 }
            for r in 0..<13 where cnt[r] == 4 { bombs[r, default: 0] += 1 }

            var run = 0, best = 0
            for r in 0..<12 { if cnt[r] > 0 { run += 1; best = max(best, run) } else { run = 0 } }
            if best >= 5 { st.straight += 1 }
            run = 0; var pb = 0
            for r in 0..<12 { if cnt[r] >= 2 { run += 1; pb = max(pb, run) } else { run = 0 } }
            if pb >= 3 { st.pairlink += 1 }
            run = 0; var ab = 0
            for r in 0..<12 { if cnt[r] >= 3 { run += 1; ab = max(ab, run) } else { run = 0 } }
            if ab >= 2 { st.airplane += 1 }
        }
        let f = Double(samples)
        st.key11 = st.key11 / f * 100
        st.key12 = st.key12 / f * 100
        st.key13 = st.key13 / f * 100
        st.key14 = st.key14 / f * 100
        st.straight = st.straight / f * 100
        st.pairlink = st.pairlink / f * 100
        st.airplane = st.airplane / f * 100
        st.bigPower = st.bigPower / f
        st.bombList = bombs.filter { Double($0.value) / f >= 0.03 }
            .map { (rank: $0.key, p: Double($0.value) / f * 100) }
            .sorted { $0.p > $1.p }
        return st
    }

    static func threatLevel(_ s: GameState, _ who: String) -> (level: Double, star: Int, rem: Int) {
        guard let st = analyzeOpponent(s, who, 400) else { return (0, 0, 0) }
        let rem = st.n
        var score = 0.0
        if rem <= 2 { score += 60 } else if rem <= 4 { score += 45 }
        else if rem <= 6 { score += 30 } else if rem <= 8 { score += 18 } else { score += 8 }
        let bombP = st.bombList.reduce(0) { $0 + $1.p }
        score += min(30, bombP * 0.6)
        score += min(20, st.key13 * 0.15 + st.key14 * 0.15 + st.key12 * 0.05)
        let star = score >= 80 ? 5 : score >= 62 ? 4 : score >= 46 ? 3 : score >= 32 ? 2 : 1
        return (score, star, rem)
    }

    // MARK: - 建议引擎
    static func comboName(_ c: Combo) -> String {
        switch c.type {
        case "single": return "单张 " + ranks[c.rank]
        case "pair": return "对子 " + ranks[c.rank]
        case "triple": return "三张 " + ranks[c.rank]
        case "bomb": return "炸弹 " + ranks[c.rank]
        case "rocket": return "王炸"
        case "straight": return "顺子 " + ranks[c.rank] + "~" + ranks[c.rank + c.len - 1] + "(\(c.len)张)"
        case "pairlink": return "连对 " + ranks[c.rank] + "~" + ranks[c.rank + c.len - 1]
        case "airplane": return "飞机 " + ranks[c.rank] + "~" + ranks[c.rank + c.len - 1]
        case "triple1": return "三带一 " + ranks[c.rank] + "带" + ranks[c.wings[0]]
        case "triple2": return "三带二 " + ranks[c.rank] + "带" + ranks[c.wings[0]]
        case "airplane1": return "飞机带单 " + ranks[c.rank] + "~" + ranks[c.rank + c.len - 1]
        case "airplane2": return "飞机带对 " + ranks[c.rank] + "~" + ranks[c.rank + c.len - 1]
        case "four2": return "四带二 " + ranks[c.rank]
        case "four22": return "四带两对 " + ranks[c.rank]
        default: return "牌型"
        }
    }

    struct Suggestion {
        var kind: String      // lead | beat | pass | wait | none
        var title: String
        var text: String
        var target: String? = nil
        var moves: [(combo: Combo, name: String, reason: String)] = []
    }

    static func reasonLead(_ move: Combo, _ handTotal: Int) -> String {
        var r: [String] = []
        if move.type == "single" {
            if move.rank <= 6 { r.append("出小单剥牌") }
            else if move.rank == 12 { r.append("2先出手，保留大王控制") }
            else { r.append("出单张过渡") }
        }
        if move.type == "pair" { r.append("先出小对子") }
        if move.type == "straight" { r.append("走顺子，压缩手牌数") }
        if move.type == "triple" || move.type == "triple1" || move.type == "triple2" { r.append("三带快速减牌") }
        if move.type == "bomb" { r.append("(不建议开局丢炸)") }
        if move.type == "pairlink" || move.type == "airplane" { r.append("长牌型一次清牌") }
        if handTotal - move.size <= 2 { r.append("出完可走，全力冲刺") }
        return r.isEmpty ? "常规出牌" : r.joined(separator: "；")
    }

    static func reasonBeat(_ move: Combo, _ target: Combo, _ enemyRem: Int) -> String {
        var r: [String] = []
        if move.type == "bomb" { r.append("被迫用炸弹压" + comboName(target)) }
        else { r.append("以" + comboName(move) + "压过" + comboName(target)) }
        if enemyRem <= 2 { r.append("对手仅剩\(enemyRem)张，必须拦截") }
        else if move.type == "single" && move.rank == 12 { r.append("消耗2抢回牌权") }
        return r.joined(separator: "；")
    }

    static func suggest(_ s: GameState) -> Suggestion {
        let myHand = s.myHand
        let mine = sum(myHand)
        if mine == 0 { return Suggestion(kind: "none", title: "你已出完", text: "恭喜，本局已胜出（或等待判定）。") }
        if s.turn != "me" {
            return Suggestion(kind: "wait", title: "等待出牌",
                              text: "当前轮到「\(nameOf(s.turn))」出牌。请先记录他们的出牌；若他们要不起，请点【过】。")
        }
        let target: Combo? = (s.lastPlayWho != nil && s.lastPlayWho != "me") ? s.lastPlayCombo : nil
        if let t = target {
            let moves = genMoves(myHand).filter { beats($0, t) && $0.type != "other" }
            if moves.isEmpty {
                return Suggestion(kind: "pass", title: "要不起",
                                  text: "对方打出 " + comboName(t) + "，你没有能压过的牌，建议直接【过】。")
            }
            let scored = moves.map { ($0, scoreBeat($0, t, myHand, s)) }.sorted { $0.1 > $1.1 }
            let best = scored[0]
            let enemy = s.lastPlayWho!
            let enemyRem = remOf(s, enemy)
            let passBetter = best.1 < -35 && enemyRem > 2
            if passBetter {
                return Suggestion(kind: "pass", title: "建议过",
                                  text: "要压 " + comboName(t) + " 需要动用大牌/炸弹，收益不高，建议【过】，保留实力。")
            }
            let top = scored.prefix(3).map { (combo: $0.0, name: comboName($0.0), reason: reasonBeat($0.0, t, enemyRem)) }
            return Suggestion(kind: "beat", title: "该你压牌", text: "", target: comboName(t), moves: Array(top))
        }
        let moves2 = genMoves(myHand).filter { $0.type != "other" }
        if moves2.isEmpty { return Suggestion(kind: "none", title: "无可出牌型", text: "请检查手牌录入是否正确。") }
        let scored2 = moves2.map { ($0, scoreLead($0, myHand, s)) }.sorted { $0.1 > $1.1 }
        let top2 = scored2.prefix(3).map { (combo: $0.0, name: comboName($0.0), reason: reasonLead($0.0, mine)) }
        return Suggestion(kind: "lead", title: "轮到你出牌", text: "", moves: Array(top2))
    }

    static func describeHand(_ hand: [Int]) -> String {
        var out: [String] = []
        let moves = genMoves(hand)
        var hasStraight = false, hasPairlink = false, hasAirplane = false
        for m in moves {
            if m.type == "straight" { hasStraight = true }
            if m.type == "pairlink" { hasPairlink = true }
            if m.type == "airplane" { hasAirplane = true }
        }
        var singles = 0, pairs = 0, tris = 0, bombs = 0
        for r in 0..<n {
            if hand[r] == 1 { singles += 1 }
            if hand[r] >= 2 { pairs += 1 }
            if hand[r] >= 3 { tris += 1 }
            if hand[r] >= 4 { bombs += 1 }
        }
        if bombs > 0 { out.append("炸弹 \(bombs) 手") }
        if hasStraight { out.append("可组顺子") }
        if hasPairlink { out.append("可组连对") }
        if hasAirplane { out.append("可组飞机") }
        if tris > 0 { out.append("三张 \(tris) 组") }
        if pairs > 0 { out.append("对子 \(pairs) 组") }
        if singles > 0 { out.append("单张 \(singles) 张") }
        return out.isEmpty ? "（空手牌）" : out.joined(separator: "、")
    }

    // MARK: - 牌局动作
    @discardableResult
    static func applyPlay(_ s: GameState, _ who: String, _ combo: Combo) -> Bool {
        let cc = comboCounts(combo)
        for r in 0..<n {
            if who == "me" {
                if cc[r] > s.myHand[r] { return false }
            } else {
                if cc[r] + s.pPlayed[who]![r] > full[r] { return false }
            }
        }
        for r in 0..<n {
            s.pPlayed[who]![r] += cc[r]
            s.played[r] += cc[r]
            if who == "me" { s.myHand[r] -= cc[r] }
        }
        s.lastPlayWho = who
        s.lastPlayCombo = combo
        s.turn = nextOf(who)
        s.log.append("\(nameOf(who))：出 " + comboName(combo))
        return true
    }

    @discardableResult
    static func applyPass(_ s: GameState, _ who: String) -> Bool {
        s.pPass[who, default: 0] += 1
        s.turn = nextOf(who)
        s.log.append("\(nameOf(who))：要不起（过）")
        return true
    }

    // 随机示例手牌（供体验/测试）
    static func randomHand(_ count: Int) -> [Int] {
        var deck: [Int] = []
        for r in 0..<n { for _ in 0..<full[r] { deck.append(r) } }
        deck.shuffle()
        var hand = arr0()
        for i in 0..<count { hand[deck[i]] += 1 }
        return hand
    }
}
