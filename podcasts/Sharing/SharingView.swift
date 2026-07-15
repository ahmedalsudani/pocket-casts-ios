import SwiftUI
import Kingfisher
import PocketCastsDataModel
import PocketCastsUtils

class ClipTime: ObservableObject {
    @Published var start: TimeInterval
    @Published var end: TimeInterval
    @Published var playback: TimeInterval

    private let originalStart: TimeInterval
    private let originalEnd: TimeInterval

    var startChanged: Bool {
        return start != originalStart
    }

    var endChanged: Bool {
        return end != originalEnd
    }

    init(start: TimeInterval, end: TimeInterval, playback: TimeInterval? = nil) {
        self.start = start
        self.end = end
        self.playback = start
        self.originalStart = start
        self.originalEnd = end
    }
}

struct SharingView: View {

    private enum Constants {
        static let descriptionMaxWidth: CGFloat = 200
        static let artworkMaxSize: CGFloat = 240
    }

    let destinations: [ShareDestination]
    let source: AnalyticsSource

    @State private var option: SharingModal.Option
    @State private var isExporting: Bool = false

    @ObservedObject var clipTime: ClipTime

    private let clipUUID = UUID().uuidString

    init(destinations: [ShareDestination], selectedOption: SharingModal.Option, source: AnalyticsSource) {
        self.destinations = destinations
        self.option = selectedOption

        switch selectedOption {
        case .clip(let episode, let time):
            let clipDuration: TimeInterval = 60
            var startTime = time
            var endTime = time + clipDuration
            if endTime > episode.duration {
                startTime = episode.duration - clipDuration
                endTime = episode.duration
            }
            self.clipTime = ClipTime(start: startTime, end: endTime, playback: time)
        default:
            self.clipTime = ClipTime(start: 0, end: 0)
        }

        self.source = source
    }

    var body: some View {
        VStack {
            title
            artwork
            SharingFooterView(clipTime: clipTime, option: $option, isExporting: $isExporting, destinations: destinations, clipUUID: clipUUID, source: source)
        }
        .onAppear {
            var properties = [:]
            let type: String

            switch option {
            case .clip(let episode, _):
                properties["episode_uuid"] = episode.uuid
                type = "clip"
            case .clipShare(let episode, _):
                properties["episode_uuid"] = episode.uuid
                type = "clip"
            case .episode(let episode):
                properties["episode_uuid"] = episode.uuid
                type = "episode"
            case .podcast(let podcast):
                properties["podcast_uuid"] = podcast.uuid
                type = "podcast"
            case .currentPosition(let episode, _), .bookmark(let episode, _):
                properties["episode_uuid"] = episode.uuid
                type = "episode_timestamp"
            }
            properties["clip_uuid"] = clipUUID
            properties["type"] = type

            Analytics.track(.shareScreenShown, source: source, properties: properties)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color.white)
    }

    @ViewBuilder var title: some View {
        VStack {
            Text(option.shareTitle)
                .font(.headline)
            switch option {
            case .clipShare(let episode, let clipTime):
                Button(action: {
                    Analytics.track(.shareScreenEditButtonTapped)
                    withAnimation {
                        option = .clip(episode, clipTime.playback)
                    }
                }) {
                    Text(L10n.editClip)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.2))
                        )
                }
                .padding(.top, 14)
            default:
                EmptyView()
            }
            Text(option.shareDescription ?? "‏")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Constants.descriptionMaxWidth)
                .accessibilityHidden(option.shareDescription == nil)
        }
    }

    @ViewBuilder var artwork: some View {
        VStack {
            Spacer()
            KFImage(option.artworkURL)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: Constants.artworkMaxSize, maxHeight: Constants.artworkMaxSize)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SharingView(destinations: [.copyLink], selectedOption: .podcast(Podcast.previewPodcast()), source: .player)
        .background(Color.black)
}
