import SwiftUI
import EndOfYear

// Many of these can be replaced with UIContentUnavailableConfigurations in iOS 17
struct ContentUnavailableConfiguration {
    static func loading() -> UIContentConfiguration {
        return UIHostingConfiguration {
            LoadingView().environmentObject(Theme.shared)
        }
    }

    static func noResults() -> UIContentConfiguration {
        return UIHostingConfiguration {
            NoResultsView().environmentObject(Theme.shared)
        }
    }

    static func empty() -> UIContentConfiguration {
        return UIHostingConfiguration {
            EmptyView()
        }
    }

    static func emptyState<Style: EmptyStateViewStyle>(
        title: String,
        message: String?,
        icon: (() -> Image)? = nil,
        actions: [EmptyStateAction] = [],
        style: Style = DefaultEmptyStateStyle.defaultStyle
    ) -> UIContentConfiguration {
        return UIHostingConfiguration {
            EmptyStateView(title: title, message: message, icon: icon, actions: actions, style: style)
                .environmentObject(Theme.shared)
        }
    }
}

struct LoadingView: View {
    @EnvironmentObject private var theme: Theme
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .padding()
                .tint(theme.primaryIcon01)
        }
        .frame(maxWidth: .infinity)
    }
}

struct NoResultsView: View {
    @EnvironmentObject private var theme: Theme

    var body: some View {
        VStack(spacing: 12) {
            Image("discover_noresult", label: Text("No Results"))
            VStack(spacing: 10) {
                Text(L10n.discoverNoPodcastsFound)
                    .font(Font.system(size: 17))
                Text(L10n.discoverNoPodcastsFoundMsg)
                    .font(Font.system(size: 14))
            }
            .foregroundStyle(theme.primaryText01)
        }
    }
}
