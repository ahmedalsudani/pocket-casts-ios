import SwiftUI
import UIKit

/// The Discover tab. There is no catalogue to browse in this build, so the tab is a search screen:
/// a search bar over a prompt, with the results shown on top once a search starts.
class DiscoverCollectionViewController: PCViewController {
    private enum Item: Hashable {
        case searchPrompt
    }

    private(set) lazy var collectionView: UICollectionView = {
        UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Int, Item>!

    private(set) lazy var searchController: PCSearchBarController = {
        PCSearchBarController()
    }()

    lazy var searchResultsController = SearchResultsViewController(showLocalResults: false)

    var resultsControllerDelegate: SearchResultsDelegate {
        searchResultsController
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.discover

        handleThemeChanged()
        setupCollectionView()
        setupSearchBar()
        configureDataSource()

        addCustomObserver(Constants.Notifications.miniPlayerDidDisappear, selector: #selector(miniPlayerStatusDidChange))
        addCustomObserver(Constants.Notifications.miniPlayerDidAppear, selector: #selector(miniPlayerStatusDidChange))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchController.beginAppearanceTransition(true, animated: animated)
        searchController.endAppearanceTransition()

        miniPlayerStatusDidChange()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        searchController.beginAppearanceTransition(false, animated: animated)
        searchController.endAppearanceTransition()
    }

    override func handleThemeChanged() {
        collectionView.backgroundColor = ThemeColor.primaryUi02()
        collectionView.reloadData()
    }

    override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        false
    }

    @objc private func miniPlayerStatusDidChange() {
        let miniPlayerOffset = Constants.effectiveMiniPlayerOffset
        collectionView.contentInset = UIEdgeInsets(top: PCSearchBarController.defaultHeight, left: 0, bottom: miniPlayerOffset, right: 0)
        collectionView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: miniPlayerOffset, right: 0)
    }
}

// MARK: - Collection View

private extension DiscoverCollectionViewController {
    func setupCollectionView() {
        collectionView.collectionViewLayout = createLayout()
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func configureDataSource() {
        let searchPromptRegistration = UICollectionView.CellRegistration<UICollectionViewCell, Item> { cell, _, _ in
            cell.contentConfiguration = ContentUnavailableConfiguration.emptyState(
                title: L10n.searchPodcasts,
                message: L10n.searchLabel,
                icon: { Image("discover_noresult") }
            )
        }

        dataSource = UICollectionViewDiffableDataSource<Int, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: searchPromptRegistration, for: indexPath, item: item)
        }

        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        snapshot.appendItems([.searchPrompt])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(0.8))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsetsReference = .none

        return UICollectionViewCompositionalLayout(section: section)
    }
}

// MARK: - Search

private extension DiscoverCollectionViewController {
    func setupSearchBar() {
        collectionView.delegate = self // For the UIScrollViewDelegate callbacks

        addCustomObserver(Constants.Notifications.tappedOnSelectedTab, selector: #selector(checkForScrollTap(_:)))

        searchController.install(in: self, attachedTo: collectionView)
        searchController.searchDebounce = Settings.podcastSearchDebounceTime()
        searchController.searchDelegate = self
    }

    @objc func checkForScrollTap(_ notification: Notification) {
        guard let index = notification.object as? Int, index == tabBarItem.tag else { return }

        let defaultOffset = -PCSearchBarController.defaultHeight - view.safeAreaInsets.top
        if collectionView.contentOffset.y.rounded(.down) > defaultOffset.rounded(.down) {
            collectionView.setContentOffset(CGPoint(x: 0, y: defaultOffset), animated: true)
        } else if searchController.cancelButtonShowing {
            // a second tap on the tab dismisses a search that's already active
            searchController.cancelTapped(self)
        } else {
            searchController.searchTextField.becomeFirstResponder()
        }
    }
}

extension DiscoverCollectionViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard searchResultsController.view?.superview == nil else { return } // don't send scroll events while the search results are up

        searchController.parentScrollViewDidScroll(scrollView)
    }
}

extension DiscoverCollectionViewController: PCSearchBarDelegate {
    func searchDidBegin() {
        guard let searchView = searchResultsController.view, searchView.superview == nil else {
            return
        }

        searchView.alpha = 0
        addChild(searchResultsController)
        // Manually drive appearance because `shouldAutomaticallyForwardAppearanceMethods` is `false`;
        // without this the hosting controller's SwiftUI view doesn't pick up the parent's bottom safe area,
        // so search results scroll under the mini player.
        searchResultsController.beginAppearanceTransition(true, animated: false)
        view.addSubview(searchView)
        searchResultsController.didMove(toParent: self)

        searchView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            searchView.topAnchor.constraint(equalTo: searchController.view.bottomAnchor)
        ])

        UIView.animate(withDuration: Constants.Animation.defaultAnimationTime) {
            searchView.alpha = 1
        }
        searchResultsController.endAppearanceTransition()
    }

    func searchDidEnd() {
        guard let searchView = searchResultsController.view else { return }

        searchResultsController.beginAppearanceTransition(false, animated: false)
        UIView.animate(withDuration: Constants.Animation.defaultAnimationTime, animations: {
            searchView.alpha = 0
        }) { _ in
            searchView.removeFromSuperview()
            self.searchResultsController.endAppearanceTransition()
            self.resultsControllerDelegate.clearSearch()
        }
    }

    func searchWasCleared() {
        resultsControllerDelegate.clearSearch()
    }

    func searchTermChanged(_ searchTerm: String) {}

    func performSearch(searchTerm: String, triggeredByTimer: Bool, completion: @escaping (() -> Void)) {
        resultsControllerDelegate.performSearch(searchTerm: searchTerm, triggeredByTimer: triggeredByTimer, completion: completion)
    }
}
