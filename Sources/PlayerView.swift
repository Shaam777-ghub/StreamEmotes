import SwiftUI
import WebKit

/// Twitch embeds require a real HTTPS parent domain with a matching host.
/// Host a simple page containing the official Twitch embed on your own domain.
struct PlayerView: View {
    let channel: String
    @AppStorage("playerBaseURL") private var playerBaseURL = ""
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(spacing: 8) {
            let base = playerBaseURL.isEmpty ? "https://shaam777-ghub.github.io/StreamEmotes/player" : playerBaseURL
            if let host = URL(string: base), host.scheme == "https", host.host != nil,
               let url = URL(string: base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/?channel=\(channel)") {
                EmbeddedWebView(url: url)
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
            } else {
                ZStack {
                    Rectangle().fill(.black)
                    VStack(spacing: 10) {
                        Image(systemName: "play.rectangle.fill").font(.system(size: 46)).foregroundStyle(.purple)
                        Text("Настройте HTTPS-страницу плеера в параметрах")
                            .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.white)
                    }.padding()
                }
                .frame(height: 220)
            }
            Button("Открыть трансляцию в Twitch") {
                if let url = URL(string: "https://www.twitch.tv/\(channel)") { openURL(url) }
            }.font(.subheadline)
        }
    }
}

struct EmbeddedWebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.scrollView.isScrollEnabled = false
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        if view.url != url { view.load(URLRequest(url: url)) }
    }
}
