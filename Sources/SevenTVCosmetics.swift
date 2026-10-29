import Foundation
import SwiftUI

struct SevenTVStyle {
    let badgeURL: URL?
    let badgeName: String?
    let gradientStops: [Gradient.Stop]
    let angle: Double
    let solidColor: Color?

    var hasPaint: Bool { !gradientStops.isEmpty || solidColor != nil }
}

/// REST v3 fallback: user cosmetic assignments are keyed by Twitch numeric user-id.
/// Some 7TV deployments expose an alternate response envelope; both are supported.
@MainActor
final class SevenTVCosmetics: ObservableObject {
    @Published private(set) var styles: [String: SevenTVStyle] = [:]
    private var pending = Set<String>()
    private var failed = Set<String>()
    private var fetchedCount = 0
    private let maxUniqueUsers = 300

    func style(for userID: String?) -> SevenTVStyle? {
        guard let userID else { return nil }
        return styles[userID]
    }

    func request(_ userID: String?) {
        guard let userID, !userID.isEmpty, fetchedCount < maxUniqueUsers,
              styles[userID] == nil, !pending.contains(userID), !failed.contains(userID) else { return }
        pending.insert(userID)
        fetchedCount += 1
        Task {
            defer { pending.remove(userID) }
            guard let url = URL(string: "https://7tv.io/v3/users/twitch/\(userID)") else { return }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 8
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    failed.insert(userID); return
                }
                // API responses contain the user either at root or under "user".
                let user = (json["user"] as? [String: Any]) ?? json
                let styleData = (user["style"] as? [String: Any]) ?? (json["style"] as? [String: Any]) ?? [:]
                if let parsed = Self.parse(styleData) { styles[userID] = parsed }
                else { failed.insert(userID) }
            } catch { failed.insert(userID) }
        }
    }

    func reset() { pending.removeAll(); failed.removeAll(); styles.removeAll(); fetchedCount = 0 }

    private static func parse(_ style: [String: Any]) -> SevenTVStyle? {
        let badge = style["badge"] as? [String: Any]
        let host = badge?["host"] as? [String: Any]
        let files = host?["files"] as? [[String: Any]] ?? []
        let file = files.first(where: { ($0["name"] as? String)?.contains("2x") == true }) ?? files.first
        var badgeURL: URL?
        if let base = host?["url"] as? String {
            let address = base.hasPrefix("//") ? "https:" + base : base
            if let name = file?["name"] as? String {
                badgeURL = URL(string: address.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + name)
            }
        }
        if badgeURL == nil, let id = badge?["id"] as? String {
            badgeURL = URL(string: "https://cdn.7tv.app/badge/\(id)/2x")
        }

        let paint = style["paint"] as? [String: Any] ?? [:]
        let gradients = paint["gradients"] as? [[String: Any]] ?? []
        let firstGradient = gradients.first ?? paint
        let stops = firstGradient["stops"] as? [[String: Any]] ?? []
        let mapped: [Gradient.Stop] = stops.compactMap { stop in
            guard let color = parseColor(stop["color"]) else { return nil }
            let raw = (stop["at"] as? NSNumber)?.doubleValue ?? 0
            return Gradient.Stop(color: color, location: min(1, max(0, raw > 1 ? raw / 100 : raw)))
        }
        let angle = (firstGradient["angle"] as? NSNumber)?.doubleValue ?? 90
        let solid = parseColor(paint["color"] ?? style["color"])
        if badgeURL == nil && mapped.isEmpty && solid == nil { return nil }
        return SevenTVStyle(badgeURL: badgeURL,
                            badgeName: badge?["name"] as? String,
                            gradientStops: mapped.sorted(by: { $0.location < $1.location }),
                            angle: angle,
                            solidColor: solid)
    }

    private static func parseColor(_ input: Any?) -> Color? {
        guard let input else { return nil }
        let number: UInt64
        if let n = input as? NSNumber { number = n.uint64Value }
        else if let s = input as? String, let n = UInt64(s.replacingOccurrences(of: "#", with: ""), radix: 16) { number = n }
        else { return nil }
        return Color(red: Double((number >> 16) & 255) / 255,
                     green: Double((number >> 8) & 255) / 255,
                     blue: Double(number & 255) / 255)
    }
}

struct SevenTVNickname: View {
    let name: String
    let fallback: Color
    let cosmetic: SevenTVStyle?
    var body: some View {
        if let cosmetic, cosmetic.gradientStops.count >= 2 {
            let radians = cosmetic.angle * .pi / 180
            Text(name).font(.caption.bold())
                .foregroundStyle(LinearGradient(stops: cosmetic.gradientStops,
                    startPoint: UnitPoint(x: 0.5 - cos(radians)/2, y: 0.5 - sin(radians)/2),
                    endPoint: UnitPoint(x: 0.5 + cos(radians)/2, y: 0.5 + sin(radians)/2)))
        } else {
            Text(name).font(.caption.bold()).foregroundStyle(cosmetic?.solidColor ?? fallback)
        }
    }
}
