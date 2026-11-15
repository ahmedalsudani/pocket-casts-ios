import SwiftUI
import PocketCastsDataModel
import CoreMedia

struct MediaTrimBar: View {
    @ObservedObject var clipTime: ClipTime

    @State var isPlaying: Bool = false

    let episode: Episode
    private let playbackManager = ClipPlaybackManager.shared

    private enum Constants {
        static var trimBorderColor = Color(hex: "6B6B6B").opacity(0.28)
        static var borderRadius: CGFloat = 12
        static var height: CGFloat = 70
    }

    init(clipTime: ClipTime, episode: Episode) {
        self.clipTime = clipTime
        self.episode = episode
        self.isPlaying = false
    }

    var body: some View {
        HStack(spacing: 0) {
            TrimPlayButton(isPlaying: $isPlaying)
                .frame(width: Constants.height)
                .background(Constants.trimBorderColor)
                .clipShape(.rect(topLeadingRadius: Constants.borderRadius,
                                 bottomLeadingRadius: Constants.borderRadius,
                                 bottomTrailingRadius: 0,
                                 topTrailingRadius: 0))
                .onChange(of: isPlaying) { _, isPlaying in
                    if isPlaying {
                        playbackManager.play(episode: episode, clipTime: _clipTime)
                    } else {
                        playbackManager.stop()
                    }
                }
                .onDisappear {
                    playbackManager.stop()
                }
            MediaTrimView(duration: episode.duration, startTime: $clipTime.start, endTime: $clipTime.end, playTime: $clipTime.playback)
                .onChange(of: clipTime.playback) { _, newValue in
                    if let currentTime = playbackManager.currentTime, abs(currentTime - newValue) > 0.1 {
                        playbackManager.seek(to: CMTime(seconds: newValue, preferredTimescale: 600))
                    }
                    playbackManager.currentTime = newValue
                }
        }
    }
}
