import Combine
import SwiftUI
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit

class UploadedViewController: PCViewController, UserEpisodeDetailProtocol {
    private let episodesDataManager = EpisodesDataManager()
    private var cancellables = Set<AnyCancellable>()

    @IBOutlet var uploadsTable: ThemeableTable! {
        didSet {
            registerLongPress()
            if LiquidGlass.isEnabled {
                uploadsTable.themeStyle = .primaryUi02
            }
            uploadsTable.allowsMultipleSelectionDuringEditing = true
            uploadsTable.rowHeight = UITableView.automaticDimension
            uploadsTable.estimatedRowHeight = 80
            uploadsTable.sectionHeaderHeight = CGFloat.leastNonzeroMagnitude
            uploadsTable.estimatedSectionHeaderHeight = CGFloat.leastNonzeroMagnitude
            uploadsTable.sectionHeaderTopPadding = 0
        }
    }

    var uploadedEpisodes = [UserEpisode]() {
        didSet {
            setNeedsUpdateContentUnavailableConfiguration()
        }
    }
    var userEpisodeDetailVC: UserEpisodeDetailViewController?

    override func updateContentUnavailableConfiguration(using state: UIContentUnavailableConfigurationState) {
        var config: UIContentConfiguration?

        if uploadedEpisodes.isEmpty {
            let title = L10n.fileUploadNoFilesTitle
            let message = L10n.fileUploadNoFilesDescription
            config = ContentUnavailableConfiguration.emptyState(title: title, message: message, icon: { Image("profile_files") }, actions: [
                .init(title: L10n.fileUploadAddFile) { [weak self] in
                    self?.addFile()
                },
                .init(id: L10n.fileUploadNoFilesHelper) {
                    Button(action: { [weak self] in
                        self?.howTo()
                    }, label: {
                        Text(L10n.fileUploadNoFilesHelper)
                            .font(.body)
                    }).buttonStyle(SimpleTextButtonStyle(theme: .shared, textColor: .primaryInteractive01))
                }
            ])
        }

        self.contentUnavailableConfiguration = config
    }

    @MainActor
    var isMultiSelectEnabled = false {
        didSet {
            setupNavBar()
            setHidesEnclosingTabBar(isMultiSelectEnabled, animated: false)
            uploadsTable.beginUpdates()
            uploadsTable.setEditing(isMultiSelectEnabled, animated: true)
            insetAdjuster.isMultiSelectEnabled = isMultiSelectEnabled
            uploadsTable.endUpdates()

            if isMultiSelectEnabled {
                multiSelectActionBar.setSelectedCount(count: selectedEpisodes.count)
                multiSelectActionBarBottomConstraint.constant = Constants.effectiveFooterViewPadding
                if let selectedIndexPath = longPressMultiSelectIndexPath {
                    uploadsTable.selectIndexPath(selectedIndexPath)
                    longPressMultiSelectIndexPath = nil
                }
            } else {
                selectedEpisodes.removeAll()
            }
        }
    }

    var multiSelectGestureInProgress = false
    var longPressMultiSelectIndexPath: IndexPath?
    @IBOutlet var multiSelectActionBar: MultiSelectFooterView! {
        didSet {
            multiSelectActionBar.delegate = self
            multiSelectActionBar.getActionsFunc = Settings.fileMultiSelectActions
            multiSelectActionBar.setActionsFunc = Settings.updateFilesMultiSelectActions
        }
    }

    @IBOutlet var multiSelectActionBarBottomConstraint: NSLayoutConstraint!

    var selectedEpisodes = [UserEpisode]() {
        didSet {
            multiSelectActionBar.setSelectedCount(count: selectedEpisodes.count)
            updateSelectAllBtn()
        }
    }

    // MARK: - View Methods

    override func viewDidLoad() {
        setupNavBar()
        super.viewDidLoad()

        registerCells()
        title = L10n.files
        (view as? ThemeableView)?.style = .primaryUi02

        insetAdjuster.setupInsetAdjustmentsForMiniPlayer(scrollView: uploadsTable)
        reloadLocalFiles()

        listenForChangedBookmarks()
    }

    var fileURL: URL?
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.shadowImage = nil

        reloadLocalFiles()
        addUIObservers()

        if let fileURL {
            let addCustomVC = AddCustomViewController(fileUrl: fileURL)

            present(SJUIUtils.popupNavController(for: addCustomVC), animated: true, completion: nil)
            self.fileURL = nil
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeAllCustomObservers()
    }

    // MARK: - App Backgrounding

    override func handleAppWillBecomeActive() {
        reloadLocalFiles()
        addUIObservers()
    }

    override func handleAppDidEnterBackground() {
        // we don't need to keep our UI up to date while backgrounded, so remove all the notification observers we have
        removeAllCustomObservers()
    }

    private func addUIObservers() {
        // TODO: a table diff might be more efficient here (and have nicer animations)

        addCustomObserver(Constants.Notifications.userEpisodeDeleted, selector: #selector(handleReloadFromNotification))
        addCustomObserver(Constants.Notifications.playbackFailed, selector: #selector(handleReloadFromNotification))
        addCustomObserver(Constants.Notifications.episodePlayStatusChanged, selector: #selector(handleReloadFromNotification))
        addCustomObserver(Constants.Notifications.episodeDownloadStatusChanged, selector: #selector(handleReloadFromNotification))
        addCustomObserver(Constants.Notifications.manyEpisodesChanged, selector: #selector(handleReloadFromNotification))
    }

    func setupNavBar() {
        supportsGoogleCast = isMultiSelectEnabled ? false : true
        let rightButton = isMultiSelectEnabled ? UIBarButtonItem(title: L10n.cancel, style: .plain, target: self, action: #selector(cancelTapped)) : UIBarButtonItem(image: UIImage(named: "more"), style: .plain, target: self, action: #selector(menuTapped))
        rightButton.accessibilityLabel = isMultiSelectEnabled ? L10n.accessibilityCancelMultiselect : L10n.accessibilitySortAndOptions
        super.setCustomRightBtn(rightButton, animated: true)

        navigationItem.setLeftBarButton(isMultiSelectEnabled ? UIBarButtonItem(title: L10n.selectAll, style: .plain, target: self, action: #selector(selectAllTapped)) : nil, animated: true)
        navigationItem.setHidesBackButton(isMultiSelectEnabled, animated: true)
    }

    @objc private func menuTapped(_ sender: UIBarButtonItem) {
        let optionsPicker = OptionsPicker(title: nil)

        let addFileAction = OptionAction(label: L10n.fileUploadAddFile, icon: "filter_add") { [weak self] in
            self?.addFile()
        }
        optionsPicker.addAction(action: addFileAction)

        let MultiSelectAction = OptionAction(label: L10n.selectEpisodes, icon: "option-multiselect") { [weak self] in
            self?.isMultiSelectEnabled = true
        }
        optionsPicker.addAction(action: MultiSelectAction)

        let currentSort = UploadedSort(rawValue: Settings.userEpisodeSortBy)
        let sortAction = OptionAction(label: L10n.sortBy, secondaryLabel: currentSort?.description ?? "", icon: "podcastlist_sort") {
        }
        sortAction.submenu = { [weak self] in self?.makeSortByPicker() }
        optionsPicker.addAction(action: sortAction)

        let settingsAction = OptionAction(label: L10n.settingsFiles, icon: "podcast-settings") { [weak self] in
            self?.navigationController?.pushViewController(UploadedSettingsViewController(), animated: true)
        }
        optionsPicker.addAction(action: settingsAction)

        optionsPicker.present(from: self)
    }

    @objc private func handleReloadFromNotification() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.reloadLocalFiles()
        }
    }

    func reloadLocalFiles() {
        uploadedEpisodes = episodesDataManager.uploadedEpisodes()
        uploadsTable.isHidden = (uploadedEpisodes.isEmpty)

        uploadsTable.reloadData()
    }

    func howTo() {
        let howToView = HowToUploadView { [weak self] in self?.dismiss(animated: true) }.environmentObject(Theme.shared)
        let navController = SJUIUtils.navController(for: UIHostingController(rootView: howToView))
        present(navController, animated: true, completion: nil)
    }

    func addFile() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: FileTypeUtil.supportedUserFileTypes, asCopy: true)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .overFullScreen
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }

    func makeSortByPicker() -> OptionsPicker {
        let optionsPicker = OptionsPicker(title: L10n.sortBy.localizedUppercase)

        UploadedSort.allCases.forEach { sort in
            optionsPicker.addAction(action: createSortAction(sort: sort))
        }

        return optionsPicker
    }

    private func createSortAction(sort: UploadedSort) -> OptionAction {
        let action = OptionAction(label: sort.description, selected: sort.rawValue == Settings.userEpisodeSortBy) {
            Settings.userEpisodeSortBy = sort.rawValue

            self.reloadLocalFiles()
        }

        return action
    }

    // NARK :- UserEpisodeDetailViewControllerDelegate
    func showEdit(userEpisode: UserEpisode) {
        let editVC = AddCustomViewController(episode: userEpisode)
        navigationController?.pushViewController(editVC, animated: true)
    }

    func showDeleteConfirmation(userEpisode: UserEpisode) {
        UserEpisodeManager.presentDeleteOptions(episode: userEpisode, from: self) {
            self.reloadLocalFiles()
        }
    }

    func userEpisodeDetailClosed() {
        userEpisodeDetailVC = nil
    }

    func closeAllChildrenViewControllers() {
        if let openAddFilesVC = presentedViewController?.children.first as? AddCustomViewController {
            openAddFilesVC.cancelTapped()
        }
        if let openUserEpiosdeDetails = userEpisodeDetailVC {
            openUserEpiosdeDetails.close()
        }
    }

    override func handleThemeChanged() {
        uploadsTable.reloadData()
    }
}

private extension UploadedViewController {
    func listenForChangedBookmarks() {
        let manager = PlaybackManager.shared.bookmarkManager

        manager.onBookmarkCreated
            .filter { $0.podcast == nil }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleReloadFromNotification()
            }
            .store(in: &cancellables)

        manager.onBookmarksDeleted
            .filter { $0.items.contains(where: { $0.podcast == nil }) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleReloadFromNotification()
            }
            .store(in: &cancellables)
    }
}

extension UploadedViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        let addCustomVC = AddCustomViewController(fileUrl: url)
        present(SJUIUtils.popupNavController(for: addCustomVC), animated: true, completion: nil)
    }
}
