import Foundation
import NIOCore

public final class GameSession: @unchecked Sendable, Identifiable {
    public let id: String
    public let roomID: String
    private let continuation: AsyncStream<ByteBuffer>.Continuation

    public init(id: String, roomID: String, continuation: AsyncStream<ByteBuffer>.Continuation) {
        self.id = id
        self.roomID = roomID
        self.continuation = continuation
    }

    public func send(_ buffer: ByteBuffer) {
        continuation.yield(buffer)
    }

    public func send(bytes: [UInt8]) {
        continuation.yield(ByteBuffer(bytes: bytes))
    }

    public func close() {
        continuation.finish()
    }
}
