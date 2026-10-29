import Foundation

@MainActor
final class ChatService: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var connected = false
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var channel = ""

    func connect(channel: String) {
        disconnect()
        self.channel = channel.lowercased()
        messages = []
        guard let url = URL(string: "wss://irc-ws.chat.twitch.tv:443") else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()
        receiveTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Anonymous read-only session. Sending chat needs a separate OAuth implementation.
                try await task.send(.string("CAP REQ :twitch.tv/tags twitch.tv/commands\r\n"))
                try await task.send(.string("PASS SCHMOOPIIE\r\n"))
                try await task.send(.string("NICK justinfan\(Int.random(in: 10000...99999))\r\n"))
                try await task.send(.string("JOIN #\(self.channel)\r\n"))
                self.connected = true
                while !Task.isCancelled {
                    let result = try await task.receive()
                    let raw: String
                    switch result {
                    case .string(let value): raw = value
                    case .data(let value): raw = String(decoding: value, as: UTF8.self)
                    @unknown default: continue
                    }
                    for line in raw.components(separatedBy: "\r\n") { await self.process(line, socket: task) }
                }
            } catch {
                if !Task.isCancelled { self.messages.append(ChatMessage(author: "Система", text: "Чат отключён: \(error.localizedDescription)", isSystem: true)) }
            }
            self.connected = false
        }
    }

    private func process(_ line: String, socket: URLSessionWebSocketTask) async {
        if line.hasPrefix("PING") {
            try? await socket.send(.string(line.replacingOccurrences(of: "PING", with: "PONG", range: line.startIndex..<line.index(line.startIndex, offsetBy: 4)) + "\r\n"))
            return
        }
        guard let range = line.range(of: " PRIVMSG #"),
              let trailing = line.range(of: " :", range: range.upperBound..<line.endIndex) else { return }
        let text = String(line[trailing.upperBound...])
        let tags = line.hasPrefix("@") ? String(line.prefix(while: { $0 != " " })) : ""
        let fields = Dictionary(uniqueKeysWithValues: tags.dropFirst().split(separator: ";").compactMap { field -> (String, String)? in
            let kv = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2 else { return nil }
            return (String(kv[0]), String(kv[1]))
        })
        let prefix = String(line[..<range.lowerBound])
        let nick = prefix.split(separator: "!").first?.split(separator: ":").last.map(String.init) ?? "user"
        let author = fields["display-name"].flatMap { $0.isEmpty ? nil : $0 } ?? nick
        messages.append(ChatMessage(author: author, text: text, color: fields["color"]))
        if messages.count > 250 { messages.removeFirst(messages.count - 250) }
    }

    func disconnect() {
        receiveTask?.cancel(); receiveTask = nil
        pingTask?.cancel(); pingTask = nil
        socket?.cancel(with: .normalClosure, reason: nil); socket = nil
        connected = false
    }
}
