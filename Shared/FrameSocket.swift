import Foundation
import Darwin

/// 屏幕帧传输用 Socket（POSIX / BSD socket，App 与 Broadcast Extension 之间经本地回环 127.0.0.1 通信）
/// 协议：每条消息 = 4字节大端长度 + 负载（JPEG 帧数据或 UTF-8 控制指令）

enum FrameSocketConfig {
    static let port: UInt16 = 49494
    static let maxMessage = 8_000_000
}

/// 服务器端（App 内使用）：监听、接收 Extension 推送的帧
final class FrameSocketServer {
    private var listenFD: Int32 = -1
    private var clientFD: Int32 = -1
    private var thread: Thread?
    private var running = false
    private let queue = DispatchQueue(label: "ddjipai.frameserver")
    var onFrame: ((Data) -> Void)?
    var onStatus: ((String) -> Void)?

    func start(port: UInt16 = FrameSocketConfig.port) {
        guard !running else { return }
        running = true
        thread = Thread { [weak self] in self?.serverLoop(port: port) }
        thread?.start()
    }

    func stop() {
        running = false
        if clientFD >= 0 { Darwin.close(clientFD); clientFD = -1 }
        if listenFD >= 0 { Darwin.close(listenFD); listenFD = -1 }
    }

    private func serverLoop(port: UInt16) {
        let s = socket(AF_INET, SOCK_STREAM, 0)
        guard s >= 0 else { onStatus?("创建socket失败"); running = false; return }
        var opt: Int32 = 1
        setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bindRes = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindRes == 0 else {
            let msg = String(cString: strerror(errno))
            onStatus?("bind失败(\(msg))，可能端口被占用")
            Darwin.close(s); running = false; return
        }
        listen(s, 4)
        listenFD = s
        onStatus?("等待屏幕录制连接…")

        while running {
            var clientAddr = sockaddr()
            var len = socklen_t(MemoryLayout<sockaddr>.size)
            let c = accept(s, &clientAddr, &len)
            if c < 0 { break }
            clientFD = c
            onStatus?("已连接（正在接收画面）")
            var header = [UInt8](repeating: 0, count: 4)
            while running {
                var n = read(c, &header, 4)
                if n <= 0 { break }
                let msgLen = Int(header[0]) << 24 | Int(header[1]) << 16 | Int(header[2]) << 8 | Int(header[3])
                if msgLen <= 0 || msgLen > FrameSocketConfig.maxMessage { break }
                var data = Data()
                data.reserveCapacity(msgLen)
                var remaining = msgLen
                var chunk = [UInt8](repeating: 0, count: 65536)
                while remaining > 0 {
                    n = read(c, &chunk, min(remaining, chunk.count))
                    if n <= 0 { break }
                    data.append(contentsOf: chunk[0..<n])
                    remaining -= n
                }
                if data.count == msgLen {
                    onFrame?(data)
                }
            }
            Darwin.close(c)
            clientFD = -1
            onStatus?("连接已断开（结束录制或切换了录制目标）")
        }
        if listenFD >= 0 { Darwin.close(listenFD); listenFD = -1 }
    }
}

/// 客户端（Broadcast Upload Extension 内使用）：连接 App 服务器并推送帧
final class FrameSocketClient {
    private var fd: Int32 = -1
    private(set) var isConnected = false
    private let host: String
    private let port: UInt16

    init(host: String = "127.0.0.1", port: UInt16 = FrameSocketConfig.port) {
        self.host = host
        self.port = port
    }

    func connect() {
        guard fd < 0 else { return }
        let s = socket(AF_INET, SOCK_STREAM, 0)
        guard s >= 0 else { return }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(host)
        let r = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if r == 0 {
            fd = s
            isConnected = true
        } else {
            Darwin.close(s)
        }
    }

    func send(_ data: Data) {
        guard isConnected, fd >= 0 else { return }
        var header: [UInt8] = [
            UInt8((data.count >> 24) & 0xFF),
            UInt8((data.count >> 16) & 0xFF),
            UInt8((data.count >> 8) & 0xFF),
            UInt8(data.count & 0xFF)
        ]
        writeAll(&header, 4)
        data.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                writeAll(UnsafeMutableRawPointer(mutating: base).assumingMemoryBound(to: UInt8.self), data.count)
            }
        }
    }

    func sendControl(_ text: String) {
        guard let d = text.data(using: .utf8) else { return }
        send(d)
    }

    private func writeAll(_ buf: UnsafeMutablePointer<UInt8>, _ len: Int) {
        var sent = 0
        while sent < len {
            let n = write(fd, buf.advanced(by: sent), len - sent)
            if n <= 0 { isConnected = false; return }
            sent += n
        }
    }

    func close() {
        if fd >= 0 { Darwin.close(fd); fd = -1 }
        isConnected = false
    }
}
