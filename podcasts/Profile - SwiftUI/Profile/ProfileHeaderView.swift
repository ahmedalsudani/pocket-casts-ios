import PocketCastsUtils
import SwiftUI

/// A view that displays the listening stats on the profile view
struct ProfileHeaderView: View {
    @EnvironmentObject var theme: Theme
    @ObservedObject var viewModel: ProfileHeaderViewModel

    /// Update the UI depending on the size of the screen
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private func rowLayout<Content: View>(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: spacing))
            : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
        return layout(content)
    }

    private func isShowingVertically(width: CGFloat) -> Bool {
        sizeClass == .compact || width < 720 || dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        container { _ in
            stats()
        }
    }

    // MARK: - Private: Views

    /// Renders the podcast, listening, and saved time stats
    private func stats() -> some View {
        // Stats
        rowLayout(alignment: .top) {
            let stats = viewModel.stats

            // Podcast Count
            StatView(value: stats.podcastCount, labels: .init(nonPlural: L10n.podcastSingular, plural: L10n.podcastsPlural))

            // Listening Time
            StatView(formatValues: stats.listeningTime.formatValues, labels: [
                .day: .init(nonPlural: L10n.dayListened, plural: L10n.daysListened),
                .minute: .init(nonPlural: L10n.minuteListened, plural: L10n.minutesListened),
                .hour: .init(nonPlural: L10n.hourListened, plural: L10n.hoursListened),
                .second: .init(nonPlural: L10n.secondsListened, plural: L10n.secondsListened)
            ])

            // Time Saved
            StatView(formatValues: stats.savedTime.formatValues, labels: [
                .day: .init(nonPlural: L10n.daySaved, plural: L10n.daysSaved),
                .minute: .init(nonPlural: L10n.minuteSaved, plural: L10n.minutesSaved),
                .hour: .init(nonPlural: L10n.hourSaved, plural: L10n.hoursSaved),
                .second: .init(nonPlural: L10n.secondsSaved, plural: L10n.secondsSaved)
            ])
        }
    }

    // MARK: - Private: Wrapper Views
    @ViewBuilder
    /// Wraps the main content in the auto sizing content height view, and adds the necessary padding
    private func container<Content: View>(@ViewBuilder _ content: @escaping (GeometryProxy) -> Content) -> some View {
        ContentSizeGeometryReader { proxy in
            contentWrapper(size: proxy.size) {
                content(proxy)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Constants.paddingTop)
            .padding(.bottom, Constants.paddingBottomAndSides)
            .padding(.horizontal, Constants.paddingBottomAndSides)
        } contentSizeUpdated: { size in
            var adjustedSize = size
            // There is an issue with this view, that when the iPad multitask mode is used, the size returns zero,
            // then the associated table view controller set a header size of zero and it never recovers from that
            if size == .zero {
                adjustedSize = Constants.minimumSize
            }
            viewModel.contentSizeChanged(adjustedSize)
        }
    }

    @ViewBuilder
    /// Wraps the content in an HStack on wide screens like iPad, and a VStack on compact ones like iPhone
    private func contentWrapper<Content: View>(size: CGSize, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        if isShowingVertically(width: size.width) {
            VStack(spacing: Constants.spacing) {
                content()
            }
        } else {
            HStack {
                Spacer()

                HStack(spacing: Constants.spacing) {
                    content()
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: -

    // MARK: StatView: Renders the stat value + label
    private struct StatView: View {
        @EnvironmentObject var theme: Theme

        let value: Int
        let label: String?

        /// Takes just a value and determines which label to display depending on if it's singular or not
        init(value: Int, labels: PluralStrings) {
            self.value = value
            self.label = value == 1 ? labels.nonPlural : labels.plural
        }

        /// Maps a the "time format" to the correct labels, in the tuple $0 is singular and $1 is plural
        init(formatValues: Double.TimeFormatValueType, labels: [Double.TimeFormatUnit: PluralStrings]) {
            let (value, unit) = formatValues
            let intValue = Int(value)

            self.value = intValue
            self.label = labels[unit].map { intValue == 1 ? $0.nonPlural : $0.plural }
        }

        var body: some View {
            label.map { label in
                VStack(spacing: 4) {
                    Text("\(value.abbreviated)")
                        .font(size: 18, style: .body, weight: .bold)
                        .foregroundColor(theme.primaryText01)

                    Text(label.localizedUppercase)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .font(style: .caption2, weight: .semibold)
                        .foregroundColor(theme.primaryText02)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }

        struct PluralStrings {
            let nonPlural: String
            let plural: String
        }
    }

    // MARK: - View Constants
    private enum Constants {
        static let spacing = 16.0
        static let paddingTop = 30.0
        static let paddingBottomAndSides = 20.0
        static let minimumSize = CGSize(width: 300, height: Constants.paddingTop + Constants.paddingBottomAndSides + 60)
    }
}

// MARK: - Previews
struct ProfileHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewContent()
    }

    struct PreviewContent: View {
        var body: some View {
            VStack {
                ProfileHeaderView(viewModel: .init())
                Spacer()
            }.setupDefaultEnvironment()
        }
    }
}
