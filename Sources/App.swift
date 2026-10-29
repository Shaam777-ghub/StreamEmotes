import SwiftUI

@main
struct StreamEmotesApp: App {
    @StateObject private var twitchAuth = TwitchAuthService()
    var body: some Scene {
        WindowGroup { HomeView().environmentObject(twitchAuth) }
    }
}
