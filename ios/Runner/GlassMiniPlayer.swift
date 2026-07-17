import SwiftUI

// mini player 玻璃胶囊：封面 + 题/歌手 + 播放/下一曲，悬浮在 dock 上方；
// chrome 收缩时整条内联到图标圆钮左侧，内容不裁剪，题/歌手随剩余宽度截断。
// 点卡片本体 → openNowPlaying（Dart push 全屏播放页）；按钮回传媒体 intent。
// 封面经 AsyncImage 拉 Dart 下发的 URL——只是展示资源，不构成业务请求；
// scrim/文字对比守 HMusic 墨色纪律。
@available(iOS 26.0, *)
struct GlassMiniPlayer: View {
  @ObservedObject var state: GlassShellState
  let reduceTransparency: Bool
  let onIntent: (String, String?) -> Void

  var body: some View {
    HStack(spacing: 12) {
      artwork
      VStack(alignment: .leading, spacing: 2) {
        Text(state.trackTitle)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.primary)
          .lineLimit(1)
        Text(state.trackArtist)
          .font(.system(size: 12))
          .foregroundStyle(Color.secondary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      controls
    }
    .padding(.horizontal, 12)
    .frame(height: GlassShellMetrics.miniHeight)
    .frame(maxWidth: .infinity)
    .glassChrome(
      capsule: true,
      reduceTransparency: reduceTransparency || state.reduceTransparency
    )
    .contentShape(Capsule(style: .continuous))
    .onTapGesture { onIntent("openNowPlaying", nil) }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("正在播放：\(state.trackTitle)，\(state.trackArtist)")
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
    // 收小到 32：缩略图只做识别，不抢 dock 的视觉主导（与 Flutter 胶囊同尺寸）。
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
    HStack(spacing: 4) {
      playPauseButton
      Button {
        onIntent("next", nil)
      } label: {
        Image(systemName: "forward.fill")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(Color.primary)
          .frame(width: 40, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("下一曲")
    }
  }

  private var playPauseButton: some View {
    Button {
      onIntent("playPause", nil)
    } label: {
      Image(systemName: state.playing ? "pause.fill" : "play.fill")
        .font(.system(size: 19, weight: .semibold))
        .foregroundStyle(Color.primary)
        .frame(width: 40, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(state.playing ? "暂停" : "播放")
  }
}
