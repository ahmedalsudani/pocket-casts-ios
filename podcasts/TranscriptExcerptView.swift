import SwiftUI

protocol TranscriptExcerptViewModeling: ObservableObject {
    var loadingState: TranscriptExcerptLoadingState { get set }

    init(episodeUUID: String, podcastUUID: String, tapAction: @escaping () -> Void)

    func excerptTapped()
}

enum TranscriptExcerptLoadingState {
    case idle
    case loading
    case success
    case failure
}

class TranscriptExcerptViewModel: ObservableObject, TranscriptExcerptViewModeling {
    @Published var loadingState: TranscriptExcerptLoadingState = .success

    private let tapAction: () -> Void

    required init(
        episodeUUID: String,
        podcastUUID: String,
        tapAction: @escaping () -> Void
    ) {
        self.tapAction = tapAction
    }

    func excerptTapped() {
        guard loadingState == .success else { return }
        tapAction()
    }
}

struct TranscriptExcerptView<ViewModel: TranscriptExcerptViewModeling>: View {
    @EnvironmentObject var theme: Theme
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 16

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.clear)
                .background(theme.primaryUi02Active)
                .cornerRadius(8.0)
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 3, x: 0, y: 1
                )
                .frame(minHeight: 48.0)
            HStack(spacing: 12.0) {
                Text(L10n.viewTranscript)
                    .font(size: 15.0, style: .body, weight: .medium)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(theme.primaryText01)
                    .redacted(if: viewModel.loadingState == .loading)
                Spacer()
                Image("listview_arrow")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(theme.primaryIcon02)
                    .frame(width: iconSize/2, height: iconSize)
            }
            .padding(.horizontal, 16.0)
        }
        .padding(.horizontal, 16.0)
        .padding(.top, 16.0)
        .padding(.bottom, 14.0)
        .onTapGesture {
            viewModel.excerptTapped()
        }
    }
}

private class MockTranscriptExcerptViewModel: TranscriptExcerptViewModeling {
    @Published var loadingState: TranscriptExcerptLoadingState = .loading

    convenience init(loadingState: TranscriptExcerptLoadingState) {
        self.init(episodeUUID: "", podcastUUID: "", tapAction: {  })
        self.loadingState = loadingState
    }

    required init(episodeUUID: String, podcastUUID: String, tapAction: () -> Void) {}

    func excerptTapped() {}
}

#Preview {
    TranscriptExcerptView(viewModel: MockTranscriptExcerptViewModel(loadingState: .loading))
        .environmentObject(Theme(previewTheme: .light))
        .frame(width: 375, height: 78)
}

#Preview {
    TranscriptExcerptView(viewModel: MockTranscriptExcerptViewModel(loadingState: .success))
        .environmentObject(Theme(previewTheme: .light))
        .frame(width: 375, height: 78)
}
