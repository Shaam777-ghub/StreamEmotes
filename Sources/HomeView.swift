import SwiftUI

struct HomeView: View {
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
                        Section("Эмоции канала") {
                            TextField("Числовой Twitch User ID", text: $twitchUserID)
                                .keyboardType(.numberPad)
                            Text("Необязательно. Без ID загружаются глобальные эмоции 7TV и BTTV.")
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
    let channel: String
    let twitchUserID: String
    @StateObject private var chat = ChatService()
    @State private var emotes: [String: Emote] = [:]
    @State private var showEmotes = false
    var body: some View {
        VStack(spacing: 0) {
            PlayerView(channel: channel)
            HStack {
                Text("Чат #\(channel)").font(.headline)
                Spacer()
                Circle().fill(chat.connected ? .green : .gray).frame(width: 8, height: 8)
                Button { showEmotes.toggle() } label: { Image(systemName: "face.smiling") }
            }.padding(.horizontal).padding(.vertical, 10)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(chat.messages) { message in
                            ChatRow(message: message, emotes: emotes).id(message.id)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }
                .onChange(of: chat.messages.count) { _, _ in
                    if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            Divider()
            Text("Чат доступен для чтения. Отправка сообщений требует OAuth Twitch.")
                .font(.caption2).foregroundStyle(.secondary).padding(8)
        }
        .navigationTitle(channel)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: channel + twitchUserID) {
            chat.connect(channel: channel)
            emotes = await EmoteService().load(twitchUserID: twitchUserID)
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
}

private struct ChatRow: View {
    let message: ChatMessage
    let emotes: [String: Emote]
    var body: some View {
        if message.isSystem { Text(message.text).font(.caption).foregroundStyle(.secondary) }
        else {
            // Wrapping via SwiftUI Text; image tokens currently rendered as a horizontal flow.
            VStack(alignment: .leading, spacing: 3) {
                Text(message.author + ":").font(.caption.bold()).foregroundStyle(.purple)
                FlowTokens(text: message.text, emotes: emotes)
            }
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
