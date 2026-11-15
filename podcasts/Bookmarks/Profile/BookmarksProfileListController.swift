import Combine
import PocketCastsDataModel
import SwiftUI

@MainActor
class BookmarksProfileListController: ThemedHostingController<BookmarksProfileListView> {
    private let playbackManager: PlaybackManager
    private let bookmarkManager: BookmarkManager
    private let viewModel: BookmarkPodcastListViewModel

    init(bookmarkManager: BookmarkManager = PlaybackManager.shared.bookmarkManager,
         playbackManager: PlaybackManager = .shared) {

        self.bookmarkManager = bookmarkManager
        self.playbackManager = playbackManager

        let sortOption = Settings.profileBookmarksSort
        let viewModel = BookmarkPodcastListViewModel(podcast: nil, bookmarkManager: bookmarkManager, sortOption: sortOption)

        self.viewModel = viewModel
        super.init(rootView: .init(viewModel: viewModel))

        viewModel.router = self
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if viewModel.isMultiSelecting {
            setEnclosingTabBarHidden(true, animated: false)
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if viewModel.isMultiSelecting {
            setEnclosingTabBarHidden(false, animated: false)
        }
    }

    @MainActor dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - BookmarkListRouter

extension BookmarksProfileListController: BookmarkListRouter {
    func bookmarkPlay(_ bookmark: Bookmark) async throws {
        try await playbackManager.playBookmark(bookmark)
    }

    func bookmarkEdit(_ bookmark: Bookmark) {
        let controller = BookmarkEditTitleViewController(manager: bookmarkManager, bookmark: bookmark, state: .updating, style: .themed)

        present(controller, animated: true)
    }

    func bookmarkShare(_ bookmark: Bookmark) {
        guard let episode = bookmark.episode as? Episode else {
            return
        }
        SharingModal.show(option: .bookmark(episode, bookmark.time), in: self)
    }

    func dismissBookmarksList() {
        dismiss(animated: true)
    }
}
