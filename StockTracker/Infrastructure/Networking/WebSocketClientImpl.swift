import Foundation

public actor WebSocketClientImpl: WebSocketClient {
    private let url: URL
    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var receiveID: UUID?
    private var messageStream: AsyncThrowingStream<Data, any Error>?
    private var messageContinuation: AsyncThrowingStream<Data, any Error>.Continuation?

    public init(endpoint: String, session: URLSession = .shared) throws {
        guard
            let url = URL(string: endpoint),
            let scheme = url.scheme?.lowercased(),
            ["ws", "wss"].contains(scheme),
            url.host != nil
        else {
            throw WebSocketError.invalidURL(endpoint)
        }

        self.url = url
        self.session = session
    }

    public func connect() async throws {
        guard webSocketTask == nil else { return }

        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    task.sendPing { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            } onCancel: {
                task.cancel(with: .goingAway, reason: nil)
            }
            try Task.checkCancellation()
        } catch {
            task.cancel(with: .goingAway, reason: nil)
            if webSocketTask === task {
                webSocketTask = nil
            }
            if Task.isCancelled {
                throw CancellationError()
            }
            throw WebSocketError.connectionFailed(underlying: error)
        }
    }

    public func send(_ message: Data) async throws {
        guard let webSocketTask else { throw WebSocketError.connectionClosed }

        do {
            try await webSocketTask.send(.data(message))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw WebSocketError.sendFailed(underlying: error)
        }
    }

    public func incomingMessages() async -> AsyncThrowingStream<Data, any Error> {
        if let messageStream { return messageStream }

        let (stream, continuation) = AsyncThrowingStream<Data, any Error>.makeStream()
        messageStream = stream
        messageContinuation = continuation

        guard let webSocketTask else {
            continuation.finish(throwing: WebSocketError.connectionClosed)
            clearMessageStream()
            return stream
        }

        let receiveID = UUID()
        self.receiveID = receiveID
        continuation.onTermination = { [weak self] _ in
            Task { await self?.messageStreamTerminated(receiveID: receiveID) }
        }
        receiveTask = Task { [weak self] in
            var receiveError: WebSocketError?
            do {
                while !Task.isCancelled {
                    let message = try await webSocketTask.receive()
                    let data: Data

                    switch message {
                    case .data(let value):
                        data = value
                    case .string(let value):
                        data = Data(value.utf8)
                    @unknown default:
                        throw WebSocketError.unsupportedMessage
                    }

                    continuation.yield(data)
                }
                continuation.finish()
            } catch {
                if Task.isCancelled {
                    continuation.finish()
                } else {
                    if webSocketTask.closeCode != .invalid {
                        receiveError = .connectionClosed
                    } else if let error = error as? WebSocketError {
                        receiveError = error
                    } else {
                        receiveError = .receiveFailed(underlying: error)
                    }
                    continuation.finish(throwing: receiveError)
                }
            }
            await self?.receiveLoopDidFinish(
                receiveID: receiveID,
                failed: receiveError != nil
            )
        }

        return stream
    }

    public func disconnect() async {
        let task = webSocketTask
        let receiveTask = self.receiveTask
        webSocketTask = nil

        receiveTask?.cancel()
        self.receiveTask = nil
        receiveID = nil
        task?.cancel(with: .goingAway, reason: nil)

        messageContinuation?.finish()
        clearMessageStream()
        await receiveTask?.value
    }

    private func receiveLoopDidFinish(receiveID: UUID, failed: Bool) {
        guard self.receiveID == receiveID else { return }
        receiveTask = nil
        self.receiveID = nil
        if failed {
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
        }
        clearMessageStream()
    }

    private func messageStreamTerminated(receiveID: UUID) {
        guard self.receiveID == receiveID else { return }
        receiveTask?.cancel()
        receiveTask = nil
        self.receiveID = nil
        messageContinuation = nil
        messageStream = nil
        let task = webSocketTask
        webSocketTask = nil
        task?.cancel(with: .goingAway, reason: nil)
    }

    private func clearMessageStream() {
        messageContinuation = nil
        messageStream = nil
    }
}
