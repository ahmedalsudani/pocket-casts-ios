import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit
import SwiftUI

class ProfileViewController: PCViewController, UITableViewDataSource, UITableViewDelegate {
    private var refreshController: FullSyncRefreshController?

    @IBOutlet var footerView: UIView!
    @IBOutlet var alertIcon: UIImageView!
    @IBOutlet var lastRefreshTime: ThemeableLabel! {
        didSet {
            lastRefreshTime.style = .primaryText02
            lastRefreshTime.font = UIFont.font(with: .subheadline, maxSizeCategory: .accessibilityMedium)
            lastRefreshTime.adjustsFontForContentSizeCategory = true
        }
    }
    @IBOutlet var refreshButtonContainer: UIView!

    private var refreshButtonTitle: String = L10n.refreshNow {
        didSet {
            updateRefreshButton()
        }
    }

    private var isRefreshAnimating: Bool = false {
        didSet {
            updateRefreshButton()
        }
    }

    private var refreshButtonHostingController: UIHostingController<AnyView>?

    private func setupRefreshButton() {
        updateRefreshButton()
        if let hostingController = refreshButtonHostingController {
            hostingController.sizingOptions = .intrinsicContentSize
            addChild(hostingController)
            refreshButtonContainer.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: refreshButtonContainer.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: refreshButtonContainer.bottomAnchor),
                hostingController.view.centerXAnchor.constraint(equalTo: refreshButtonContainer.centerXAnchor),
                hostingController.view.leadingAnchor.constraint(greaterThanOrEqualTo: refreshButtonContainer.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(lessThanOrEqualTo: refreshButtonContainer.trailingAnchor)
            ])
            hostingController.didMove(toParent: self)
        }
    }

    private func updateRefreshButton() {
        let refreshButton = ProfileRefreshButton(
            title: refreshButtonTitle,
            isAnimating: isRefreshAnimating,
            action: { [weak self] in
                self?.refreshTapped()
            }
        ).setupDefaultEnvironment()

        if let hostingController = refreshButtonHostingController {
            hostingController.rootView = AnyView(refreshButton)
        } else {
            let hostingController = UIHostingController(rootView: AnyView(refreshButton))
            hostingController.view.backgroundColor = .clear
            self.refreshButtonHostingController = hostingController
        }
    }

    private let settingsCellId = "SettingsCell"
    private let endOfYearPromptCell = "EndOfYearPromptCell"

    enum TableRow { case allStats, downloaded, starred, listeningHistory, uploadedFiles, endOfYearPrompt, bookmarks }

    @IBOutlet var profileTable: UITableView! {
        didSet {
            profileTable.register(UINib(nibName: "TopLevelSettingsCell", bundle: nil), forCellReuseIdentifier: settingsCellId)
            profileTable.register(EndOfYearPromptCell.self, forCellReuseIdentifier: endOfYearPromptCell)
        }
    }

    // MARK: - Profile Header
    private lazy var headerViewModel: ProfileHeaderViewModel = {
        let viewModel = ProfileHeaderViewModel(navigationController: navigationController)

        // Listen for view size changes and update the header view cell if needed
        viewModel.viewContentSizeChanged = { [weak self] in
            self?.profileTable.reloadData()
        }

        return viewModel
    }()

    private lazy var headerView: UIView = {
        let headerView = ProfileHeaderView(viewModel: headerViewModel)

        let view = headerView.themedUIView
        view.backgroundColor = .clear

        return view
    }()

    // MARK: - View Events

    override func viewDidLoad() {
        customRightBtn = UIBarButtonItem(image: UIImage(named: "profile-settings"), style: .plain, target: self, action: #selector(settingsTapped))
        customRightBtn?.accessibilityLabel = L10n.accessibilityProfileSettings
        customRightBtn?.accessibilityIdentifier = "Settings"

        super.viewDidLoad()

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: ProfileViewController, _) in
            controller.updateFooterFrame()
        }

        navigationItem.title = L10n.profile

        profileTable.tableFooterView = footerView

        setupRefreshButton()
        updateDisplayedData()
        updateRefreshFooterColors()
        updateFooterFrame()
        setupRefreshControl()
        insetAdjuster.setupInsetAdjustmentsForMiniPlayer(scrollView: profileTable)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateDisplayedData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        addCustomObserver(ServerNotifications.podcastsRefreshed, selector: #selector(refreshComplete))
        addCustomObserver(Constants.Notifications.podcastAdded, selector: #selector(handleDataChangedNotification))
        addCustomObserver(Constants.Notifications.podcastDeleted, selector: #selector(handleDataChangedNotification))
        addCustomObserver(ServerNotifications.podcastRefreshFailed, selector: #selector(refreshComplete))
        addCustomObserver(ServerNotifications.podcastRefreshThrottled, selector: #selector(refreshComplete))
        addCustomObserver(EndOfYear.eoyEligibilityDidChange, selector: #selector(handleDataChangedNotification))

        addCustomObserver(Constants.Notifications.tappedOnSelectedTab, selector: #selector(checkForScrollTap(_:)))

        if EndOfYear.isEligible {
            NotificationCenter.postOnMainThread(notification: Constants.Notifications.profileSeen)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeAllCustomObservers()
    }

    override func handleThemeChanged() {
        updateRefreshFooterColors()
    }

    private func updateRefreshFooterColors() {
        alertIcon.tintColor = ThemeColor.primaryIcon02()
    }

    // MARK: - Actions

    @objc private func checkForScrollTap(_ notification: Notification) {
        if let index = notification.object as? Int, index == tabBarItem.tag, profileTable.contentOffset.y > 0 {
            profileTable.setContentOffset(CGPoint.zero, animated: true)
        }
    }

    @objc private func settingsTapped() {
        let settingsController = SettingsViewController()
        navigationController?.pushViewController(settingsController, animated: true)
    }

    private func refreshTapped() {
        isRefreshAnimating = true
        lastRefreshTime.text = L10n.refreshing
        RefreshManager.shared.refreshPodcasts()
    }

    // MARK: - Data Updates

    @objc private func refreshComplete() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.isRefreshAnimating = false
            self.updateLastRefreshDetails()
        }
    }

    @objc private func handleDataChangedNotification() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.updateDisplayedData()
        }
    }

    private func updateDisplayedData() {
        // Update the new header's data
        headerViewModel.update()

        updateLastRefreshDetails()
        updateFooterFrame()
        refreshTableData()
    }

    private func updateLastRefreshDetails() {
        if !ServerSettings.lastRefreshSucceeded() {
            lastRefreshTime.text = L10n.refreshFailed
            refreshButtonTitle = L10n.tryAgain
            alertIcon.isHidden = false
        } else if let lastUpdateTime = ServerSettings.lastRefreshEndTime() {
            refreshButtonTitle = L10n.refreshNow
            if abs(lastUpdateTime.timeIntervalSinceNow) > 2.days {
                lastRefreshTime.text = L10n.profileLastAppRefresh(TimeFormatter.shared.appleStyleElapsedString(date: lastUpdateTime))
                alertIcon.isHidden = false
            } else {
                lastRefreshTime.text = L10n.refreshPreviousRun(TimeFormatter.shared.appleStyleElapsedString(date: lastUpdateTime))
                alertIcon.isHidden = true
            }
        } else {
            refreshButtonTitle = L10n.refreshNow
            lastRefreshTime.text = L10n.refreshPreviousRun(L10n.timeFormatNever)
            alertIcon.isHidden = false
        }
    }

    // MARK: - UITableView

    func numberOfSections(in tableView: UITableView) -> Int {
        tableData.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableData[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = tableData[indexPath.section][indexPath.row]

        guard row != .endOfYearPrompt else {
            return tableView.dequeueReusableCell(withIdentifier: endOfYearPromptCell, for: indexPath) as! EndOfYearPromptCell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: settingsCellId, for: indexPath) as! TopLevelSettingsCell

        cell.settingsImage.tintColor = ThemeColor.primaryIcon01()
        cell.settingsLabel.setLetterSpacing(-0.01)
        cell.separatorInset = .zero

        switch row {
        case .allStats:
            cell.settingsImage.image = UIImage(named: "profile-stats")
            cell.settingsLabel.text = L10n.settingsStats
        case .downloaded:
            cell.settingsImage.image = UIImage(named: "profile-download")
            cell.settingsLabel.text = L10n.downloads
        case .uploadedFiles:
            cell.settingsImage.image = UIImage(named: "profile_files")
            cell.settingsLabel.text = L10n.files
        case .starred:
            cell.settingsImage.image = UIImage(named: "profile-star")
            cell.settingsLabel.text = L10n.statusStarred
        case .listeningHistory:
            cell.settingsImage.image = UIImage(named: "profile-history")
            cell.settingsLabel.text = L10n.listeningHistory
        case .endOfYearPrompt:
            return EndOfYearPromptCell()
        case .bookmarks:
            cell.settingsImage.image = UIImage(named: "bookmarks-profile")
            cell.settingsLabel.text = L10n.bookmarks
        }

        return cell
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        70
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = tableData[indexPath.section][indexPath.row]
        navigateToRow(row)
    }

    func navigateToRow(_ row: TableRow) {
        switch row {
        case .allStats:
            let statsViewController = StatsViewController()
            navigationController?.pushViewController(statsViewController, animated: true)
        case .downloaded:
            let downloadController = DownloadsViewController()
            navigationController?.pushViewController(downloadController, animated: true)
        case .uploadedFiles:
            let uploadedController = UploadedViewController()
            navigationController?.pushViewController(uploadedController, animated: true)
        case .starred:
            let starredController = StarredViewController()
            navigationController?.pushViewController(starredController, animated: true)
        case .listeningHistory:
            let historyController = ListeningHistoryViewController()
            navigationController?.pushViewController(historyController, animated: true)
        case .endOfYearPrompt:
            dismiss(animated: true)
            if let endOfYear = (tabBarController as? MainTabBarController)?.endOfYear {
                endOfYear.showStories(in: self)
            } else {
                //Show warning that playback is not available
                let alert = UIAlertController(title: L10n.playbackNotAvailable, message: L10n.pleaseTryAgainLater, preferredStyle: .alert)
                present(alert, animated: true)
            }
        case .bookmarks:
            let bookmarksController = BookmarksProfileListController()
            navigationController?.pushViewController(bookmarksController, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        18
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return headerViewModel.contentSize?.height ?? UITableView.automaticDimension
    }

    private var tableData: [[ProfileViewController.TableRow]] = []

    private func refreshTableData() {
        var data: [[ProfileViewController.TableRow]]
        data = [[.allStats, .downloaded, .uploadedFiles, .starred, .bookmarks, .listeningHistory]]

        if EndOfYear.isEndOfYearActive, EndOfYear.isEligible {
            data[0].insert(.endOfYearPrompt, at: 0)
        }

        tableData = data
        profileTable.reloadData()
    }

    private func updateFooterFrame() {
        footerView.setNeedsLayout()
        footerView.layoutIfNeeded()

        let targetSize = CGSize(width: profileTable.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let height = footerView.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height

        footerView.frame = CGRect(x: footerView.frame.minX, y: footerView.frame.minY, width: footerView.frame.width, height: height)
        profileTable.tableFooterView = footerView
    }
}

// MARK: - Refresh Control

extension ProfileViewController {
    private func setupRefreshControl() {
        let controller = FullSyncRefreshController()
        refreshController = controller
        profileTable.refreshControl = controller.refreshControl
    }
}
