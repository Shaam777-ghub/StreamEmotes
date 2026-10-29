import Foundation

struct Emote: Identifiable, Hashable {
    let name: String
    let url: URL
    let source: String
    var id: String { "\(source):\(name)" }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let author: String
    let text: String
    let color: String?
    let isSystem: Bool
    init(author: String, text: String, color: String? = nil, isSystem: Bool = false) {
        self.author = author; self.text = text; self.color = color; self.isSystem = isSystem
    }
}
