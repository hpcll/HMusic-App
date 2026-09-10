import SwiftUI

// 沿用原来的纤细胶囊；展开为曲名/歌手，收起时只保留曲名和播放键。
@available(iOS 26.0, *)
struct GlassMiniPlayer: View {
  @ObservedObject var state: GlassShellState
  let reduceTransparency: Bool
  let onIntent: (String, String?) -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button { onIntent("openNowPlaying", nil) } label: {
        HStack(spacing: 10) {
          artwork
          trackText
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(state.trackId == nil)
      .accessibilityLabel(state.trackId == nil
        ? "未在播放" : "\(state.trackTitle)，\(state.trackArtist)，打开播放器")
      controls
    }
    .padding(.horizontal, 12)
    .frame(height: state.miniPlayerHeight)
    .frame(maxWidth: .infinity)
    .glassChrome(
      reduceTransparency: reduceTransparency || state.reduceTransparency
    )
    .accessibilityElement(children: .contain)
  }

  private var trackText: some View {
    VStack(alignment: .leading, spacing: 2) {
      textLine(state.trackId == nil ? "未在播放" : state.trackTitle,
        size: state.miniTitleFontSize, strong: true)
      if !state.minimized && !state.trackArtist.isEmpty {
        textLine(state.trackArtist, size: state.miniDetailFontSize)
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func textLine(_ value: String, size: CGFloat, strong: Bool = false) -> some View {
    Text(value)
      .font(.system(size: size, weight: strong ? .semibold : .regular))
      .foregroundStyle(strong ? Color.primary : Color.secondary)
      .lineLimit(1)
      .truncationMode(.tail)
      .frame(height: size * 1.25)
  }

  private var artwork: some View {
    Group {
      if let url = state.artworkUrl {
        AsyncImage(url: url) { phase in
          if let image = phase.image {
            image.resizable().aspectRatio(contentMode: .fill)
          } else {
            artworkPlaceholder
          }
        }
      } else {
        artworkPlaceholder
      }
    }
    .frame(width: 32, height: 32)
    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
  }

  private var artworkPlaceholder: some View {
    ZStack {
      Color(uiColor: .secondarySystemFill)
      Image(systemName: "music.note")
        .font(.system(size: 13))
        .foregroundStyle(Color.secondary)
    }
  }

  private var controls: some View {
    HStack(spacing: 0) {
      control(
        state.playing ? "pause.fill" : "play.fill",
        label: state.playing ? "暂停" : "播放",
        intent: "playPause"
      )
      if !state.minimized {
        control("forward.fill", label: "下一首", intent: "next")
          .transition(.opacity)
      }
    }
  }

  private func control(_ symbol: String, label: String, intent: String) -> some View {
    Button { onIntent(intent, nil) } label: {
      Image(systemName: symbol)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(Color.primary)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(state.trackId == nil)
    .accessibilityLabel(label)
  }
}
