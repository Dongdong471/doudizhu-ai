import Foundation
import Combine
import UIKit

/// App 全局状态：持有引擎状态、屏幕录制管道、OCR 识别结果
final class AppState: ObservableObject {

    let engine = Engine.GameState()

    // UI 刷新 / 状态
    @Published var uiTick = 0                       // 引擎状态变化后 +1 触发视图刷新
    @Published var captureStatus = "未开始录制"
    @Published var frameCount = 0
    @Published var lastRawOCR: [String] = []
    @Published var latestFrame: UIImage?            // 最近一帧（调试预览用）
    @Published var logLines: [String] = []          // 出牌/识别流水

    // 设置
    @Published var myRole: String = "landlord"
    @Published var landlord: String = "me"
    @Published var autoRecognizeEnabled = true

    private let processor = FrameProcessor()
    private let server = FrameSocketServer()
    private var lastAppliedPlayed: [Int] = [Int](repeating: 0, count: 15)
    private var stableHand: [Int] = [Int](repeating: 0, count: 15)
    private var stableHandStreak = 0

    init() {
        server.onStatus = { [weak self] s in
            DispatchQueue.main.async { self?.captureStatus = s }
        }
        server.onFrame = { [weak self] data in self?.handleFrame(data) }
    }

    // MARK: - 屏幕录制
    func startCaptureServer() {
        server.start()
    }
    func stopCaptureServer() {
        server.stop()
    }

    // MARK: - 识别帧处理
    private func handleFrame(_ data: Data) {
        // 解码用于预览显示
        if let img = UIImage(data: data) {
            DispatchQueue.main.async { [weak self] in self?.latestFrame = img }
        }
        processor.process(jpegData: data) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.frameCount += 1
                self.lastRawOCR = Array(result.rawTexts.prefix(30))
                guard self.autoRecognizeEnabled else { return }
                self.applyRecognition(result)
            }
        }
    }

    private func applyRecognition(_ r: RecognitionResult) {
        // 1) 我的手牌：连续 2 帧识别到数量在合理范围才应用，避免误检
        let total = r.handCards.reduce(0, +)
        let expected = engine.initCounts["me"] ?? 17
        if total >= 14 && total <= expected {
            if r.handCards == stableHand {
                stableHandStreak += 1
                if stableHandStreak >= 2 && r.handCards != engine.myHand {
                    engine.myHand = r.handCards
                    log("自动识别手牌（\(total)张）：" + Engine.describeHand(r.handCards))
                    uiTick += 1
                }
            } else {
                stableHand = r.handCards
                stableHandStreak = 1
            }
        }

        // 2) 桌面出牌：与上次应用的不同且非空 → 视为新一手，记到当前出牌人
        if !r.playedCards.isEmpty && r.playedCards != lastAppliedPlayed {
            lastAppliedPlayed = r.playedCards
            if let combo = Engine.classify(r.playedCards), combo.type != "other" {
                let who = engine.turn
                if Engine.applyPlay(engine, who, combo) {
                    log("自动识别：\(Engine.nameOf(who)) 出 \(Engine.comboName(combo))")
                    uiTick += 1
                }
            }
        }
    }

    // MARK: - 手动操作（OCR 识别失败时的兜底）
    func manualPlay(_ who: String, combo: Engine.Combo) {
        if Engine.applyPlay(engine, who, combo) {
            log("手动：\(Engine.nameOf(who)) 出 \(Engine.comboName(combo))")
            uiTick += 1
        }
    }
    func manualPass(_ who: String) {
        if Engine.applyPass(engine, who) {
            log("手动：\(Engine.nameOf(who)) 过")
            uiTick += 1
        }
    }
    func manualSetHand(_ counts: [Int]) {
        engine.myHand = counts
        log("手动设置手牌（\(counts.reduce(0, +))张）")
        uiTick += 1
    }

    func newGame() {
        let lw = landlord
        let fresh = Engine.defaultState()
        Engine.setLandlord(fresh, lw)
        engine.myRole = fresh.myRole
        engine.landlord = fresh.landlord
        engine.initCounts = fresh.initCounts
        engine.myHand = fresh.myHand
        engine.played = fresh.played
        engine.pPlayed = fresh.pPlayed
        engine.pPass = fresh.pPass
        engine.log = fresh.log
        engine.turn = fresh.turn
        engine.lastPlayWho = fresh.lastPlayWho
        engine.lastPlayCombo = fresh.lastPlayCombo
        logLines.removeAll()
        lastAppliedPlayed = [Int](repeating: 0, count: 15)
        log("新开一局（地主：\(Engine.nameOf(lw))）")
        uiTick += 1
    }

    func setLandlord(_ who: String) {
        landlord = who
        myRole = (who == "me") ? "landlord" : "farmer"
        Engine.setLandlord(engine, who)
        uiTick += 1
    }

    func toggleTurn() {
        engine.turn = Engine.nextOf(engine.turn)
        uiTick += 1
    }

    func undo() {
        // 简化：撤销最近一条出牌/过牌记录（重新按日志重放不可行，仅清空对局状态需用户手动“新开一局”）
        log("撤销功能：请使用「新开一局」或手动修正")
    }

    private func log(_ s: String) {
        logLines.append(s)
        if logLines.count > 60 { logLines.removeFirst(logLines.count - 60) }
    }
}
