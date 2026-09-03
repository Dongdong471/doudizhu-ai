import ReplayKit
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// 斗地主AI记牌 · 屏幕录制上传扩展
/// 用户从控制中心开始"屏幕录制"并选择本 App 作为录制目标后，系统会把游戏画面
/// 逐帧回调到这里；本扩展将画面压缩为 JPEG 后经本地 socket 推送给主 App 做 OCR。
final class SampleHandler: RPBroadcastSampleHandler {

    private var client = FrameSocketClient(host: "127.0.0.1", port: FrameSocketConfig.port)
    private let context = CIContext()
    private var lastSendTime: TimeInterval = 0
    private let minFrameInterval: TimeInterval = 0.12   // 约 8fps，够识别牌面
    private var frameCount = 0
    private var didAnnounceReady = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // 通知主 App 开始接收
        UserDefaults(suiteName: AppGroup.identifier)?.set("START", forKey: "broadcast_status")
        client.connect()
        frameCount = 0
        lastSendTime = 0
        if client.isConnected {
            client.sendControl("HELLO")
        } else {
            // 若 App 尚未启动监听，稍后自动重连
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if !self.client.isConnected { self.client.connect() }
            }
        }
    }

    override func broadcastPaused() {
        UserDefaults(suiteName: AppGroup.identifier)?.set("PAUSE", forKey: "broadcast_status")
        client.sendControl("PAUSE")
    }

    override func broadcastResumed() {
        UserDefaults(suiteName: AppGroup.identifier)?.set("RUN", forKey: "broadcast_status")
        client.sendControl("RESUME")
    }

    override func broadcastFinished() {
        UserDefaults(suiteName: AppGroup.identifier)?.set("STOP", forKey: "broadcast_status")
        client.sendControl("STOP")
        client.close()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        // 节流
        let now = CACurrentMediaTime()
        guard now - lastSendTime >= minFrameInterval else { return }
        lastSendTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        // 缩放到合适尺寸，降低传输与 OCR 开销
        let w = image.extent.width
        let targetW: CGFloat = 720
        guard w > 0 else { return }
        let scale = targetW / w
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return }
        let ui = UIImage(cgImage: cg)
        guard let jpeg = ui.jpegData(compressionQuality: 0.55) else { return }

        if client.isConnected {
            client.send(jpeg)
        } else if !didAnnounceReady {
            // 首帧未连上时，尝试重连一次
            didAnnounceReady = true
            client.connect()
            if client.isConnected { client.send(jpeg) }
        }
        frameCount += 1
    }
}

/// App Group 标识（与主 App 一致；打包时按需修改 Bundle ID 前缀）
enum AppGroup {
    static let identifier = "group.com.doubao.ddzjipai"
}
