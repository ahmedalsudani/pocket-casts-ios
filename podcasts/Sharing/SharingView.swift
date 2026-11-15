import SwiftUI
import PocketCastsDataModel
import PocketCastsUtils

class ClipTime: ObservableObject {
    @Published var start: TimeInterval
    @Published var end: TimeInterval
    @Published var playback: TimeInterval

    init(start: TimeInterval, end: TimeInterval, playback: TimeInterval? = nil) {
        self.start = start
        self.end = end
        self.playback = start
    }
}

struct SharingView: View {

    struct Shareable {
        var option: SharingModal.Option
        var style: ShareImageStyle
    }

    private enum Constants {
        static let tabViewPadding: CGFloat = 80 // A value which represents extra padding for UIPageControl of the TabView
    }

    let destinations: [ShareDestination]

    @State private var shareable: Shareable
    @State private var isExporting: Bool = false
    @State private var episodeArtworkUrl: URL?

    @ScaledMetric(relativeTo: .subheadline) private var descriptionMaxWidth: CGFloat = 200

    @ObservedObject var clipTime: ClipTime

    private let clipUUID = UUID().uuidString

    init(destinations: [ShareDestination], selectedOption: SharingModal.Option, selectedStyle: ShareImageStyle = .large) {
        self.destinations = destinations
        self.shareable = Shareable(option: selectedOption, style: selectedStyle)

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
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack {
                    title
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)
                    tabView
                        .frame(minHeight: 220)
                    SharingFooterView(clipTime: clipTime, option: $shareable.option, isExporting: $isExporting, destinations: destinations, style: shareable.style, clipUUID: clipUUID)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, proxy.safeAreaInsets.bottom > 0 ? 0 : 20)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color.white)
        .task {
            episodeArtworkUrl = await shareable.option.loadEpisodeArtworkUrl()
        }
    }

    @ViewBuilder var title: some View {
        VStack {
            Text(shareable.option.shareTitle(style: shareable.style))
                .font(.headline)
            switch shareable.option {
            case .clipShare(let episode, let clipTime, _):
                Button(action: {
                    withAnimation {
                        shareable.option = .clip(episode, clipTime.playback)
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
            Text(shareable.style.shareDescription(option: shareable.option) ?? "‏")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: descriptionMaxWidth)
                .accessibilityHidden(shareable.style.shareDescription(option: shareable.option) == nil)
        }
    }

    private func styles(for option: SharingModal.Option) -> [ShareImageStyle] {
        switch shareable.option {
        case .clipShare(_, _, let style):
            [style]
        case .clip:
            ShareImageStyle.allCases
        default:
            ShareImageStyle.allCases.filter { $0 != .audio }
        }
    }

    @ViewBuilder var tabView: some View {
        let styles = styles(for: shareable.option)
        GeometryReader { proxy in
            let currentIndex = styles.firstIndex(of: shareable.style) ?? 0
            TabView(selection: $shareable.style) {
                ForEach(styles, id: \.self) { style in
                    image(style: style, containerHeight: proxy.size.height)
                }
            }
            .tabViewStyle(.page)
            .accessibilityElement()
            .accessibilityLabel(L10n.clipsShareableMediaA11yLabel)
            .accessibilityValue(L10n.clipsShareableMediaItemA11yLabel(shareable.style.tabString, currentIndex + 1, styles.count))
            .accessibilityAdjustableAction { direction in
                let nextIndex: Int?
                switch direction {
                case .increment:
                    nextIndex = currentIndex.advanced(by: 1) % styles.count
                case .decrement:
                    nextIndex = (currentIndex - 1 + styles.count) % styles.count
                default:
                    nextIndex = nil
                }

                shareable.style = styles[nextIndex ?? 0]
            }
        }
    }

    @ViewBuilder func image(style: ShareImageStyle, containerHeight: CGFloat) -> some View {
        ShareImageView(info: shareable.option.imageInfo(episodeArtworkUrl: episodeArtworkUrl), style: style, angle: .constant(0))
            .frame(width: style.previewSize.width, height: style.previewSize.height)
            .fixedSize()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .tabItem { Text(style.tabString) }
            .id(style)
            .scaleEffect((containerHeight - Constants.tabViewPadding) / ShareImageStyle.large.previewSize.height)
	}
}

#Preview {
    SharingView(destinations: [.copyLink], selectedOption: .podcast(Podcast.previewPodcast()))
        .background(Color.black)
}
