import Foundation

@MainActor
enum TwitchChatSender {
    static func send(_ text:String,channel:String,auth:TwitchAuthService) async throws {
        guard auth.signedIn else { throw NSError(domain:"StreamEmotes",code:1,userInfo:[NSLocalizedDescriptionKey:"Сначала войди в Twitch"]) }
        let token = auth.accessToken
        let id = auth.clientID
        var urlParts = URLComponents(string:"https://api.twitch.tv/helix/users")!
        urlParts.queryItems = [URLQueryItem(name:"login",value:channel)]
        var lookup = URLRequest(url:urlParts.url!)
        lookup.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        lookup.setValue(id,forHTTPHeaderField:"Client-Id")
        let (lookupData,lookupResponse) = try await URLSession.shared.data(for:lookup)
        guard (lookupResponse as? HTTPURLResponse)?.statusCode == 200 else { throw NSError(domain:"Twitch",code:2,userInfo:[NSLocalizedDescriptionKey:"Не получилось найти канал (проверь авторизацию)"]) }
        struct User:Decodable { let id:String }
        struct UserResponse:Decodable { let data:[User] }
        guard let broadcaster = try JSONDecoder().decode(UserResponse.self,from:lookupData).data.first else { throw NSError(domain:"Twitch",code:3,userInfo:[NSLocalizedDescriptionKey:"Канал не найден"]) }
        var request = URLRequest(url:URL(string:"https://api.twitch.tv/helix/chat/messages")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        request.setValue(id,forHTTPHeaderField:"Client-Id")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject:["broadcaster_id":broadcaster.id,"sender_id":auth.userID,"message":text])
        let (data,response) = try await URLSession.shared.data(for:request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let reason = String(data:data,encoding:.utf8) ?? "Ошибка Twitch"
            throw NSError(domain:"Twitch",code:4,userInfo:[NSLocalizedDescriptionKey:reason])
        }
        struct Result:Decodable { let is_sent:Bool; let drop_reason:Drop?; struct Drop:Decodable { let message:String? } }
        struct ResultResponse:Decodable { let data:[Result] }
        if let status = try JSONDecoder().decode(ResultResponse.self,from:data).data.first, !status.is_sent {
            throw NSError(domain:"Twitch",code:5,userInfo:[NSLocalizedDescriptionKey:status.drop_reason?.message ?? "Twitch отклонил сообщение"])
        }
    }
}
