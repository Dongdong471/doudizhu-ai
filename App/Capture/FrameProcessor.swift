import Foundation
import CoreGraphics
import Vision

/// 一帧画面的识别结果
struct RecognitionResult {
    var handCards: [Int]      // 底部"我的手牌"区识别到的 rank->count
    var playedCards: [Int]    // 桌面出牌区识别到的 rank->count
    var rawTexts: [String]    // 该帧所有识别文本（调试用）
    var frameIndex: Int = 0
}

/// 基于 Vision OCR 的牌面识别器。
/// 把屏幕划分为"我的手牌区"（底部）与"出牌区"（桌面中部），按区域把识别到的
/// 点数归类。不同斗地主 App 的牌面布局略有差异，可在设置中微调区域。
final class FrameProcessor {

    // 归一化坐标（Vision 坐标系，原点在左下角）
    struct Rect { var x: Double, y: Double, w: Double, h: Double }
    // 我的手牌：屏幕底部
    private let myHandRegion = Rect(x: 0.0, y: 0.0, w: 1.0, h: 0.20)
    // 出牌区：桌面中部（上家/我/下家打出的牌都会出现在这里）
    private let playedRegion = Rect(x: 0.0, y: 0.28, w: 1.0, h: 0.52)
    // 出牌区可能比中下部更靠上，默认取中下部

    private var frameIndex = 0

    func process(jpegData: Data, completion: @escaping (RecognitionResult) -> Void) {
        guard let image = decode(jpegData) else { return }
        recognize(image) { [weak self] observations in
            guard let self = self else { return }
            self.frameIndex += 1
            var hand = [Int](repeating: 0, count: 15)
            var played = [Int](repeating: 0, count: 15)
            var raw: [String] = []
            for obs in observations {
                guard let top = obs.topCandidates(1).first else { continue }
                let text = top.string
                raw.append(text)
                guard let rank = FrameProcessor.rank(from: text) else { continue }
                let b = obs.boundingBox   // 归一化，原点左下
                let cx = Double(b.midX)
                let cy = Double(b.midY)
                if inside(cx, cy, myHandRegion) {
                    hand[rank] += 1
                } else if inside(cx, cy, playedRegion) {
                    played[rank] += 1
                }
            }
            completion(RecognitionResult(handCards: hand, playedCards: played,
                                         rawTexts: raw, frameIndex: self.frameIndex))
        }
    }

    private func inside(_ x: Double, _ y: Double, _ r: Rect) -> Bool {
        return x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h
    }

    private func decode(_ data: Data) -> CGImage? {
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(jpegDataProviderSource: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }

    private func recognize(_ image: CGImage, completion: @escaping ([VNRecognizedTextObservation]) -> Void) {
        let request = VNRecognizeTextRequest { req, _ in
            completion((req.results as? [VNRecognizedTextObservation]) ?? [])
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.minimumTextHeight = 0.02
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }

    /// 把 OCR 文本映射为点数值（3~2、小王、大王）。容忍常见误识。
    static func rank(from text: String) -> Int? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        t = t.replacingOccurrences(of: " ", with: "")
        // 常见误识归一
        switch t {
        case "3": return 0
        case "4": return 1
        case "5": return 2
        case "6": return 3
        case "7": return 4
        case "8": return 5
        case "9": return 6
        case "10", "1O", "IO", "L0": return 7
        case "J", "J0", "J.": return 8
        case "Q", "0", "O", "Q.": return 9
        case "K", "K.": return 10
        case "A", "A.": return 11
        case "2": return 12
        case "小王", "小", "JOKER", "SMALL", "S", "BJ": return 13
        case "大王", "大", "BIG", "RJ", "JOKER2": return 14
        default: return nil
        }
    }
}
