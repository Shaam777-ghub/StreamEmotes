import Foundation
import Security

struct DeviceCode: Decodable {
    let device_code: String
    let user_code: String
    let verification_uri: String
    let expires_in: Int
    let interval: Int
}

@MainActor
final class TwitchAuthService: ObservableObject {
    @Published var clientID: String = UserDefaults.standard.string(forKey: "twitchClientID") ?? ""
    @Published private(set) var userName = ""
    @Published private(set) var userID = ""
    @Published private(set) var device: DeviceCode?
    @Published var errorText = ""
    @Published var busy = false
    private(set) var accessToken: String = ""
    private var startedAt = Date()

    init() {
        accessToken = Self.readKeychain("twitch_access") ?? ""
        if !accessToken.isEmpty { Task { await validate() } }
    }
    var signedIn: Bool { !accessToken.isEmpty && !userID.isEmpty }

    func saveClientID() { clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines); UserDefaults.standard.set(clientID, forKey: "twitchClientID") }

    func startLogin() async {
        saveClientID()
        guard !clientID.isEmpty else { errorText = "Укажи Client ID приложения Twitch"; return }
        busy = true; errorText = ""; defer { busy = false }
        do {
            let data = try await postForm("https://id.twitch.tv/oauth2/device", ["client_id":clientID,"scopes":"user:write:chat"])
            device = try JSONDecoder().decode(DeviceCode.self, from: data)
            startedAt = Date()
        } catch { errorText = "Не удалось получить код: \(error.localizedDescription)" }
    }

    func finishLogin() async {
        guard let device else { return }
        guard Date().timeIntervalSince(startedAt) < Double(device.expires_in) else { errorText = "Код истёк. Получи новый."; return }
        busy = true; errorText = ""; defer { busy = false }
        do {
            let data = try await postForm("https://id.twitch.tv/oauth2/token", [
                "client_id":clientID,
                "scopes":"user:write:chat",
                "device_code":device.device_code,
                "grant_type":"urn:ietf:params:oauth:grant-type:device_code"
            ])
            struct Tokens: Decodable { let access_token: String; let refresh_token: String? }
            let tokens = try JSONDecoder().decode(Tokens.self, from: data)
            accessToken = tokens.access_token
            Self.writeKeychain("twitch_access", accessToken)
            if let refresh = tokens.refresh_token { Self.writeKeychain("twitch_refresh", refresh) }
            await validate()
            if signedIn { self.device = nil }
        } catch { errorText = "Подтверди код на Twitch и нажми «Проверить вход». \(error.localizedDescription)" }
    }

    func validate() async {
        guard !accessToken.isEmpty else { return }
        do {
            var req = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/validate")!)
            req.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")
            let (data,response) = try await URLSession.shared.data(for:req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { logout(); return }
            struct Identity: Decodable { let login: String; let user_id: String; let client_id: String }
            let identity = try JSONDecoder().decode(Identity.self, from: data)
            guard identity.client_id == clientID else { logout(); return }
            userName = identity.login; userID = identity.user_id
        } catch { errorText = "Не удалось проверить Twitch-сессию" }
    }

    func logout() {
        accessToken = ""; userName = ""; userID = ""; device = nil
        Self.deleteKeychain("twitch_access"); Self.deleteKeychain("twitch_refresh")
    }

    private func postForm(_ address: String, _ fields: [String:String]) async throws -> Data {
        var request = URLRequest(url: URL(string:address)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type")
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name:$0.key,value:$0.value) }
        request.httpBody = (components.percentEncodedQuery ?? "").data(using:.utf8)
        let (data,response) = try await URLSession.shared.data(for:request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let payload = String(data:data,encoding:.utf8) ?? "HTTP \(status)"
            throw NSError(domain:"Twitch",code:status,userInfo:[NSLocalizedDescriptionKey:payload])
        }
        return data
    }

    private static func writeKeychain(_ key:String,_ value:String) {
        deleteKeychain(key)
        let attributes: [String:Any] = [kSecClass as String:kSecClassGenericPassword,
             kSecAttrAccount as String:key, kSecAttrService as String:"StreamEmotes.Twitch",
             kSecValueData as String:Data(value.utf8), kSecAttrAccessible as String:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        SecItemAdd(attributes as CFDictionary,nil)
    }
    private static func readKeychain(_ key:String) -> String? {
        let query:[String:Any] = [kSecClass as String:kSecClassGenericPassword,
            kSecAttrAccount as String:key,kSecAttrService as String:"StreamEmotes.Twitch",
            kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&value) == errSecSuccess,
              let data = value as? Data else { return nil }
        return String(data:data,encoding:.utf8)
    }
    private static func deleteKeychain(_ key:String) {
        let query:[String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrAccount as String:key,kSecAttrService as String:"StreamEmotes.Twitch"]
        SecItemDelete(query as CFDictionary)
    }
}
