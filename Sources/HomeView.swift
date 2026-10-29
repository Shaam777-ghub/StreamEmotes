import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: TwitchAuthService
    @AppStorage("channel") private var channel = ""
    @AppStorage("twitchUserID") private var twitchUserID = ""
    @AppStorage("playerBaseURL") private var playerBaseURL = ""
    @State private var draft = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "video.bubble.fill").font(.system(size: 54)).foregroundStyle(.purple)
                Text("StreamEmotes").font(.largeTitle.bold())
                Text("Twitch + 7TV + BetterTTV").foregroundStyle(.secondary)
                HStack {
                    TextField("Имя канала Twitch", text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.go)
                        .onSubmit(openChannel)
                    Button("Открыть", action: openChannel).buttonStyle(.borderedProminent).tint(.purple)
                }
                if !channel.isEmpty {
                    NavigationLink("Перейти в чат #\(channel)") { StreamView(channel: channel, twitchUserID: twitchUserID) }
                        .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Каналы")
            .toolbar { Button { showSettings = true } label: { Image(systemName: "gearshape") } }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    Form {
                        Section("Аккаунт Twitch") {
                            if auth.signedIn {
                                Text("Вы вошли как @\(auth.userName)")
                                Button("Выйти") { auth.logout() }
                            } else {
                                TextField("Twitch Client ID", text: $auth.clientID)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                Button("Получить код входа") { Task { await auth.startLogin() } }
                                    .disabled(auth.busy)
                                if let device = auth.device {
                                    Text("Код: \(device.user_code)").font(.headline)
                                    Link("Открыть Twitch для подтверждения", destination: URL(string:device.verification_uri)!)
                                    Button("Проверить вход") { Task { await auth.finishLogin() } }
                                        .disabled(auth.busy)
                                }
                                Text("Client ID создаётся один раз в dev.twitch.tv/console/apps. Выбери Public Client / Device Code Flow, если есть такой выбор. Не вставляй Client Secret.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if !auth.errorText.isEmpty { Text(auth.errorText).font(.caption).foregroundStyle(.red) }
                        }
                        Section("Эмоции канала") {
                            TextField("Числовой Twitch User ID", text: $twitchUserID)
                                .keyboardType(.numberPad)
                            Text("ID определяется автоматически по имени канала. Можно указать вручную, если автоопределение не работает.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Section("Встроенный плеер") {
                            TextField("https://ваш-домен.example/player", text: $playerBaseURL)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                            Text("Нужна ваша HTTPS-страница с официальным Twitch embed. Twitch проверяет параметр parent. Без настройки доступна кнопка открытия Twitch.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("Настройки")
                    .toolbar { Button("Готово") { showSettings = false } }
                }
            }
            .onAppear { draft = channel }
        }
        .preferredColorScheme(.dark)
    }
    private func openChannel() {
        let cleaned = draft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleaned.range(of: "^[a-z0-9_]{1,25}$", options: .regularExpression) != nil { channel = cleaned }
    }
}

struct StreamView: View {
    @EnvironmentObject private var auth: TwitchAuthService
    @State private var outgoing = ""
    @State private var sending = false
    @State private var sendError = ""
    let channel: String
    let twitchUserID: String
    @StateObject private var chat = ChatService()
    @StateObject private var cosmetics = SevenTVCosmetics()
    @State private var emotes: [String: Emote] = [:]
    @State private var showEmotes = false
    @AppStorage("chatShowBadges") private var showBadges = true
    @AppStorage("chatSevenTVPaints") private var showSevenTVPaints = true
    @AppStorage("chatSevenTVBadges") private var showSevenTVBadges = true
    @AppStorage("chatHighlightMentions") private var highlightMentions = true
    @AppStorage("chatRespectNameColors") private var respectNameColors = true
    var body: some View {
        VStack(spacing: 0) {
            PlayerView(channel: channel)
            HStack {
                Text("Чат #\(channel)").font(.headline)
                Spacer()
                Circle().fill(chat.connected ? .green : .gray).frame(width: 8, height: 8)
                Text("7TV / BTTV: \(emotes.count)")
                    .font(.caption2).foregroundStyle(.secondary)
                Menu {
                    Toggle("Значки Twitch", isOn: $showBadges)
                    Toggle("Значки 7TV", isOn: $showSevenTVBadges)
                    Toggle("Paints 7TV", isOn: $showSevenTVPaints)
                    Toggle("Цвета никнеймов Twitch", isOn: $respectNameColors)
                    Toggle("Подсветка упоминаний", isOn: $highlightMentions)
                } label: { Image(systemName: "textformat") }
                Button { showEmotes.toggle() } label: { Image(systemName: "face.smiling") }
            }.padding(.horizontal).padding(.vertical, 10)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(chat.messages) { message in
                            ChatRow(message: message, emotes: emotes, showBadges: showBadges, respectNameColors: respectNameColors, highlightMentions: highlightMentions, currentUser: auth.userName, sevenTVStyle: cosmetics.style(for: message.userID), sevenTVPaints: showSevenTVPaints, sevenTVBadges: showSevenTVBadges).id(message.id)
                                .onAppear { cosmetics.request(message.userID) }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }
                .onChange(of: chat.messages.count) { _, _ in
                    if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            Divider()
            if auth.signedIn {
                HStack(spacing: 8) {
                    TextField("Сообщение от @\(auth.userName)", text: $outgoing)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.send)
                        .onSubmit { Task { await sendMessage() } }
                    Button("Отправить") { Task { await sendMessage() } }
                        .disabled(sending || outgoing.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }.padding(8)
            } else {
                Text("Чтобы писать в чат, войди в Twitch через ⚙️ на главном экране.")
                    .font(.caption).foregroundStyle(.secondary).padding(8)
            }
            if !sendError.isEmpty { Text(sendError).font(.caption).foregroundStyle(.red).padding(.horizontal,8) }
        }
        .navigationTitle(channel)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: channel + twitchUserID) {
            cosmetics.reset()
            chat.connect(channel: channel)
            emotes = await EmoteService().load(channel: channel, twitchUserID: twitchUserID)
        }
        .onDisappear { chat.disconnect() }
        .sheet(isPresented: $showEmotes) {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 16) {
                        ForEach(emotes.values.sorted(by: { $0.name < $1.name })) { emote in
                            VStack(spacing: 4) {
                                AsyncImage(url: emote.url) { img in img.resizable().scaledToFit() } placeholder: { ProgressView() }
                                    .frame(width: 54, height: 54)
                                Text(emote.name).font(.caption2).lineLimit(1)
                            }
                        }
                    }.padding()
                }
                .navigationTitle("Эмоции (\(emotes.count))")
                .toolbar { Button("Закрыть") { showEmotes = false } }
            }
        }
    }
    private func sendMessage() async {
        let content = outgoing.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !sending, !content.isEmpty, content.count <= 500 else { return }
        sending = true; sendError = ""
        defer { sending = false }
        do { try await TwitchChatSender.send(content,channel:channel,auth:auth); outgoing = "" }
        catch { sendError = error.localizedDescription }
    }

}

private struct ChatRow: View {
    let message: ChatMessage
    let emotes: [String: Emote]
    let showBadges: Bool
    let respectNameColors: Bool
    let highlightMentions: Bool
    let currentUser: String
    let sevenTVStyle: SevenTVStyle?
    let sevenTVPaints: Bool
    let sevenTVBadges: Bool

    private var isMention: Bool {
        guard highlightMentions, !currentUser.isEmpty else { return false }
        return message.text.localizedCaseInsensitiveContains("@" + currentUser)
    }
    private var nickColor: Color {
        guard respectNameColors, let hex = message.color, hex.hasPrefix("#"), hex.count == 7,
              let value = UInt32(hex.dropFirst(), radix: 16) else { return .purple }
        return Color(red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255,
                     blue: Double(value & 255) / 255)
    }
    var body: some View {
        if message.isSystem { Text(message.text).font(.caption).foregroundStyle(.secondary) }
        else {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if showBadges {
                        ForEach(message.badges, id: \.self) { badge in
                            Text(badgeLabel(badge))
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 3).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))
                                .accessibilityLabel("Twitch: " + badge)
                        }
                    }
                    if sevenTVBadges, let badgeURL = sevenTVStyle?.badgeURL {
                        AsyncImage(url: badgeURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: { EmptyView() }
                        .frame(width: 18, height: 18)
                        .accessibilityLabel("7TV: " + (sevenTVStyle?.badgeName ?? "Badge"))
                    }
                    SevenTVNickname(name: message.author + ":", fallback: nickColor,
                        cosmetic: sevenTVPaints ? sevenTVStyle : nil)
                }
                FlowTokens(text: message.text, emotes: emotes)
            }
            .padding(.horizontal, isMention ? 6 : 0)
            .padding(.vertical, isMention ? 4 : 0)
            .background(isMention ? Color.yellow.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
    }
    private func badgeLabel(_ badge: String) -> String {
        switch badge {
        case "broadcaster": return "LIVE"
        case "moderator": return "MOD"
        case "vip": return "VIP"
        case "subscriber": return "SUB"
        case "founder": return "1st"
        case "staff": return "STAFF"
        default: return badge.uppercased().prefix(5).description
        }
    }
}

private struct FlowTokens: View {
    let text: String
    let emotes: [String: Emote]
    var body: some View {
        let tokens = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        // Text is wrapped as a whole when no extension emotes are present.
        if !tokens.contains(where: { emotes[$0] != nil }) {
            Text(text).font(.subheadline)
        } else {
            EmoteWrap(tokens: tokens, emotes: emotes)
        }
    }
}

private struct EmoteWrap: View {
    let tokens: [String]
    let emotes: [String: Emote]
    var body: some View {
        // Horizontal scroll prevents clipping for long sequences; future: implement wrapping Layout.
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { item in
                    let token = item.element
                    if let emote = emotes[token] {
                        AsyncImage(url: emote.url) { image in image.resizable().scaledToFit() } placeholder: { Text(token) }
                            .frame(height: 28)
                    } else {
                        Text(token).font(.subheadline)
                    }
                }
            }
        }.scrollIndicators(.hidden)
    }
}
