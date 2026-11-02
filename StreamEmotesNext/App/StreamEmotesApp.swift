import SwiftUI
import WebKit
import Security

@main
struct StreamEmotesApp: App {
    var body: some Scene {
        WindowGroup { ClientView().preferredColorScheme(.dark).ignoresSafeArea(.container) }
    }
}

struct ClientView: UIViewRepresentable {
    func makeCoordinator() -> Host { Host() }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "native")
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.bounces = false
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Host) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "native")
    }
}

final class Host: NSObject, WKScriptMessageHandler, WKNavigationDelegate, URLSessionTaskDelegate {
    weak var webView: WKWebView?
    private var playerView: WKWebView?
    private let apiHosts: Set<String> = ["api.twitch.tv", "id.twitch.tv", "api.betterttv.net", "7tv.io", "7tv.app", "api.7tv.app"]
    private let key = "com.sham.streamemotesnext.oauth"
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Do not forward authorization to another origin via redirects.
        completionHandler(nil)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.targetFrame?.isMainFrame == true, let url = action.request.url, !url.isFileURL {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.request.url?.isFileURL == true,
              let body = message.body as? [String: Any], let id = body["id"] as? Int,
              let method = body["method"] as? String else { return }
        switch method {
        case "showPlayer":
            guard let raw = body["url"] as? String, let url = URL(string: raw),
                  url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else {
                reply(id, false, error: "Некорректный адрес плеера"); return
            }
            playerView?.removeFromSuperview()
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []
            // Remote content has no access to the local application's native bridge or tokens.
            let player = WKWebView(frame: .zero, configuration: config)
            player.accessibilityIdentifier = "TwitchPlayer"
            player.scrollView.isScrollEnabled = false
            player.backgroundColor = .black
            playerView = player
            webView?.addSubview(player)
            positionPlayer(body)
            player.load(URLRequest(url: url))
            reply(id, true)
        case "playerFrame":
            positionPlayer(body)
            reply(id, true)
        case "playerVisible":
            playerView?.isHidden = !(body["visible"] as? Bool ?? false)
            reply(id, true)
        case "hidePlayer":
            playerView?.stopLoading()
            playerView?.removeFromSuperview()
            playerView = nil
            reply(id, true)
        case "readToken":
            let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key, kSecReturnData as String: true]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(q as CFDictionary, &item)
            if status == errSecSuccess, let d = item as? Data { reply(id, String(data: d, encoding: .utf8) ?? "") }
            else { reply(id, "") }
        case "writeToken":
            let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
            SecItemDelete(q as CFDictionary)
            var add = q
            add[kSecValueData as String] = (body["value"] as? String ?? "").data(using: .utf8)!
            add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let status = SecItemAdd(add as CFDictionary, nil)
            reply(id, status == errSecSuccess, error: status == errSecSuccess ? nil : "Не удалось сохранить вход")
        case "deleteToken":
            SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary)
            reply(id, true)
        case "open":
            guard let raw = body["url"] as? String, let url = URL(string: raw), url.scheme == "https",
                  ["www.twitch.tv", "twitch.tv", "id.twitch.tv"].contains(url.host ?? "") else { reply(id, false); return }
            UIApplication.shared.open(url)
            reply(id, true)
        case "http":
            guard let raw = body["url"] as? String, let url = URL(string: raw), url.scheme == "https",
                  apiHosts.contains(url.host ?? "") else { reply(id, "", error: "Адрес API запрещён"); return }
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.httpMethod = body["verb"] as? String ?? "GET"
            if let headers = body["headers"] as? [String: String] {
                for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
            }
            request.httpBody = (body["body"] as? String)?.data(using: .utf8)
            session.dataTask(with: request) { [weak self] data, response, error in
                if let error { self?.reply(id, "", error: error.localizedDescription); return }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                self?.reply(id, ["status": code, "text": String(data: data ?? Data(), encoding: .utf8) ?? ""])
            }.resume()
        default: reply(id, "", error: "Неизвестная операция")
        }
    }
    private func positionPlayer(_ body: [String: Any]) {
        guard let webView, let x = body["x"] as? Double, let y = body["y"] as? Double,
              let width = body["width"] as? Double, let height = body["height"] as? Double,
              [x, y, width, height].allSatisfy({ $0.isFinite }), width > 0, height > 0 else { return }
        playerView?.frame = CGRect(x: x, y: y, width: width, height: height).intersection(webView.bounds)
    }
    private func reply(_ id: Int, _ result: Any, error: String? = nil) {
        let payload: [String: Any] = ["id": id, "result": result, "error": error.map { $0 as Any } ?? NSNull()]
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let text = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async { [weak self] in self?.webView?.evaluateJavaScript("window.nativeReply(\(text))", completionHandler: nil) }
    }
}
