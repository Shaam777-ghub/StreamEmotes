# StreamEmotes — Native SwiftUI Twitch chat client (iOS 17+)

## Included
- Native SwiftUI navigation and chat UI
- Live read-only Twitch chat via anonymous IRC WebSocket
- Global BetterTTV + 7TV emotes, plus channel emotes when numeric Twitch user ID is supplied
- Configurable HTTPS embedded player page and fallback to twitch.tv

## Build on Mac
1. Install Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. From the project directory run `xcodegen generate`.
3. Open `StreamEmotes.xcodeproj` in Xcode.
4. Select your Apple development team in Signing & Capabilities and replace `com.example.StreamEmotes` with your unique bundle identifier.
5. Select an iPhone and press Run.

No third-party Swift packages are required.

## Optional embedded player (HTTPS host required)
Twitch requires official embedded player usage and a matching `parent` domain. You must host a page on HTTPS, e.g. `https://yourdomain.example/player/`, and enter that URL in the app settings. Here is a sample page (`player-template.html`); **set `parent` to your actual page host** and ensure the iframe uses Twitch's required dimensions. Mobile playback requires a tap. A webpage placed on an arbitrary / nonexistent host will not work.

## Known limitations / next milestones
- This is an initial development prototype, **not** a verified App Store-ready build.
- No authenticated login, followed channel list, chat sending, badges, Twitch's own emotes, channel-ID discovery, auto-scrolling preferences, or picture-in-picture yet.
- SwiftUI `AsyncImage` is not guaranteed to animate WebP/GIF; animated emotes require a dedicated animated image renderer.
- Native video playback is **not** implemented. Player works only with properly hosted Twitch embed; fallback opens official Twitch.
- Twitch recommends EventSub/API for new chat integrations. Anonymous IRC is used here for a simple read-only MVP.
- 7TV/BTTV APIs may change; error states currently fall back to fewer emotes.
- No Xcode/iOS SDK is available in this runtime, so sources have not been compiled on an Apple toolchain.

References: https://dev.twitch.tv/docs/chat/irc ; https://dev.twitch.tv/docs/embed/video-and-clips/ ; https://betterttv.com/developers ; https://github.com/SevenTV/API

## Windows-only unsigned IPA workflow (GitHub Actions + AltStore)
1. Create a GitHub repository and upload the **contents of this StreamEmotes directory to the repository root**, including `.github/workflows/ios-unsigned.yml` (hidden folder).
2. Open repository > Actions > **Build iOS IPA (unsigned)** > Run workflow. It also runs on pushes to `main`.
3. If the job succeeds, download the `StreamEmotes-unsigned-IPA` artifact and extract the IPA from its ZIP.
4. Install AltServer/AltStore Classic on Windows/iPhone, per https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows, then import `StreamEmotes-unsigned.ipa` with AltStore. AltStore signs it using your Apple account; the unsigned IPA alone cannot be installed.
5. Free Apple accounts typically need refresh every 7 days. No paid Apple Developer membership is needed for this *sideloading* workflow, but availability and success can depend on Apple/iOS signing rules.

This workflow has not been run in GitHub Actions; compilation is not verified, and any compiler errors will need fixing using the Actions log. Twitch video playback requires configuring a separate valid HTTPS embed host.
