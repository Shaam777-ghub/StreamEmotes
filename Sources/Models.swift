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
    // Twitch IRC user-id tag, used by 7TV cosmetics.
    let userID: String
    // Twitch IRC badges tag, e.g. "moderator/1,subscriber/6".
    let badges: [String]

    init(author: String, text: String, color: String? = nil,
         isSystem: Bool = false, userID: String = "", badges: [String] = []) {
        self.author = author
        self.text = text
        self.color = color
        self.isSystem = isSystem
        self.userID = userID
        self.badges = badges
    }
}
