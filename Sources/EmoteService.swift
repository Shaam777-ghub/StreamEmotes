import Foundation

/// Fetches public emotes without storing any user credentials.
actor EmoteService {
    private struct BTTVEmote: Decodable { let id: String; let code: String }
    private struct BTTVUser: Decodable {
        let channelEmotes: [BTTVEmote]
        let sharedEmotes: [BTTVEmote]
    }
    private struct SevenTVSet: Decodable { let emotes: [SevenTVEmote] }
    private struct SevenTVEmote: Decodable {
        let name: String
        let data: SevenTVData?
    }
    private struct SevenTVData: Decodable { let host: SevenTVHost? }
    private struct SevenTVHost: Decodable { let url: String; let files: [SevenTVFile] }
    private struct SevenTVFile: Decodable { let name: String }
    private struct SevenTVUser: Decodable {
        struct PartialSet: Decodable { let id: String?; let emotes: [SevenTVEmote]? }
        let emote_set: PartialSet?
        let emote_set_id: String?
    }

    func load(channel: String, twitchUserID: String?) async -> [String: Emote] {
        // Channel APIs need numeric Twitch ID, not channel login.
        let manual = twitchUserID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolved = manual.isEmpty ? await resolveTwitchID(channel: channel) : manual
        async let bttvGlobal = fetchBTTVGlobal()
        async let sevenGlobal = fetchSevenTVGlobal()
        var collections = await [bttvGlobal, sevenGlobal]
        if !resolved.isEmpty, resolved.allSatisfy(\.isNumber) {
            let id = resolved
            async let bttvUser = fetchBTTVUser(id)
            async let sevenUser = fetchSevenTVUser(id)
            collections += await [bttvUser, sevenUser]
        }
        var result: [String: Emote] = [:]
        for collection in collections {
            for emote in collection { result[emote.name] = emote }
        }
        return result
    }

    private func get<T: Decodable>(_ url: String, as: T.Type) async -> T? {
        guard let url = URL(string: url) else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch { return nil }
    }

    private func convertBTTV(_ emotes: [BTTVEmote]) -> [Emote] {
        emotes.compactMap { e in
            guard let url = URL(string: "https://cdn.betterttv.net/emote/\(e.id)/2x") else { return nil }
            return Emote(name: e.code, url: url, source: "BTTV")
        }
    }
    private func convertSevenTV(_ emotes: [SevenTVEmote]) -> [Emote] {
        emotes.compactMap { e in
            guard let host = e.data?.host, let file = host.files.first(where: { $0.name.contains("2x") && $0.name.hasSuffix(".webp") }) ?? host.files.first else { return nil }
            let base = host.url.hasPrefix("//") ? "https:" + host.url : host.url
            guard let url = URL(string: base + "/" + file.name) else { return nil }
            return Emote(name: e.name, url: url, source: "7TV")
        }
    }
    private func resolveTwitchID(channel: String) async -> String {
        let login = channel.lowercased()
        guard login.range(of: "^[a-z0-9_]{1,25}$", options: .regularExpression) != nil,
              let url = URL(string: "https://decapi.me/twitch/id/\(login)") else { return "" }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return "" }
            let id = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return !id.isEmpty && id.allSatisfy(\.isNumber) ? id : ""
        } catch { return "" }
    }

    private func fetchBTTVGlobal() async -> [Emote] {
        convertBTTV(await get("https://api.betterttv.net/3/cached/emotes/global", as: [BTTVEmote].self) ?? [])
    }
    private func fetchBTTVUser(_ id: String) async -> [Emote] {
        guard let user = await get("https://api.betterttv.net/3/cached/users/twitch/\(id)", as: BTTVUser.self) else { return [] }
        return convertBTTV(user.channelEmotes + user.sharedEmotes)
    }
    private func fetchSevenTVGlobal() async -> [Emote] {
        guard let set = await get("https://7tv.io/v3/emote-sets/global", as: SevenTVSet.self) else { return [] }
        return convertSevenTV(set.emotes)
    }
    private func fetchSevenTVUser(_ id: String) async -> [Emote] {
        guard let user = await get("https://7tv.io/v3/users/twitch/\(id)", as: SevenTVUser.self) else { return [] }
        if let direct = user.emote_set?.emotes, !direct.isEmpty {
            return convertSevenTV(direct)
        }
        guard let setID = user.emote_set_id ?? user.emote_set?.id, !setID.isEmpty,
              let set = await get("https://7tv.io/v3/emote-sets/\(setID)", as: SevenTVSet.self) else { return [] }
        return convertSevenTV(set.emotes)
    }
}
