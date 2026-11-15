import PocketCastsServer
import PocketCastsUtils
import SwiftUI
import UIKit
import UniformTypeIdentifiers

class SettingsViewController: PCViewController, UITableViewDataSource, UITableViewDelegate {
    enum TableRow: String {
        case general, notifications, appearance, storageAndDataUse
        case autoArchive, autoDownload, autoAddToUpNext, siriShortcuts
        case customFiles, importSteps, opml
        case about
        case upNextHistory
        case troubleshooting, logs, exportDatabase
        case headphoneControls
        case beta

        var display: (text: String, image: UIImage?) {
            switch self {
            case .general:
                return (L10n.settingsGeneral, UIImage(named: "profile-settings"))
            case .notifications:
                return (L10n.settingsNotifications, UIImage(named: "settings_notifications"))
            case .appearance:
                return (L10n.settingsAppearance, UIImage(named: "settings_appearance"))
            case .storageAndDataUse:
                return (L10n.settingsStorage, UIImage(named: "settings_storage"))
            case .autoArchive:
                return (L10n.settingsAutoArchive, UIImage(named: "settings_archive"))
            case .autoAddToUpNext:
                return (L10n.settingsAutoAdd, UIImage(named: "playlast"))
            case .autoDownload:
                return (L10n.settingsAutoDownload, UIImage(named: "settings_autodownload"))
            case .importSteps:
                return (L10n.welcomeImportButton, UIImage(named: "settings_import_podcasts"))
            case .opml:
                return (L10n.exportPodcastsOption, UIImage(named: "settings_export_podcasts"))
            case .about:
                return (L10n.settingsAbout, UIImage(named: "settings_about"))
            case .siriShortcuts:
                return (L10n.settingsSiriShortcuts, UIImage(named: "settings_shortcuts"))
            case .customFiles:
                return (L10n.files, UIImage(named: "profile_files"))
            case .beta:
                return ("Beta Features", UIImage(systemName: "testtube.2"))
            case .headphoneControls:
                return (L10n.settingsHeadphoneControls, .init(named: "settings_headphone_controls"))
            case .upNextHistory:
                return (L10n.upNextHistory, .init(named: "upnext"))
            case .troubleshooting:
                return (L10n.troubleshootingTitle, UIImage(systemName: "stethoscope"))
            case .logs:
                return (L10n.logs, UIImage(systemName: "doc.text"))
            case .exportDatabase:
                return (L10n.exportDatabase, UIImage(systemName: "externaldrive"))
            }
        }
    }

    private var tableData: [[TableRow]] = []

    private var databaseExport: DatabaseExport?
    private var loadingAlert: ShiftyLoadingAlert?

    /// All the possible settings sections
    private let allSections: [[TableRow]] = {
        #if DEBUG
        let developerSection: [TableRow] = [.beta]
        #else
        let developerSection: [TableRow] = []
        #endif

        return [
            developerSection,
            [.general, .notifications, .appearance],
            [.autoArchive, .autoDownload, .autoAddToUpNext],
            [.storageAndDataUse, .siriShortcuts, .headphoneControls, .customFiles],
            [.importSteps, .opml],
            [.upNextHistory],
            [.troubleshooting, .logs, .exportDatabase],
            [.about]
        ]
    }()

    private let settingsCellId = "SettingsCell"

    @IBOutlet var settingsTable: UITableView! {
        didSet {
            settingsTable.register(UINib(nibName: "TopLevelSettingsCell", bundle: nil), forCellReuseIdentifier: settingsCellId)
            settingsTable.rowHeight = UITableView.automaticDimension
            settingsTable.estimatedRowHeight = UITableView.automaticDimension
            settingsTable.sectionHeaderHeight = UITableView.automaticDimension
            settingsTable.estimatedSectionHeaderHeight = Constants.Values.tableSectionHeaderHeight
            settingsTable.sectionFooterHeight = UITableView.automaticDimension
            settingsTable.estimatedSectionFooterHeight = Constants.Values.tableSectionHeaderHeight
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.settings
        insetAdjuster.setupInsetAdjustmentsForMiniPlayer(scrollView: settingsTable)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reloadTable()
    }

    // MARK: - UITableView Methods

    func numberOfSections(in tableView: UITableView) -> Int {
        tableData.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableData[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: settingsCellId, for: indexPath) as! TopLevelSettingsCell
        cell.showsPlusIndicator = false

        let tableRow = tableData[indexPath.section][indexPath.row]
        cell.settingsLabel.text = tableRow.display.text
        cell.settingsLabel.accessibilityIdentifier = tableRow.rawValue
        cell.settingsImage.image = tableRow.display.image

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let tableRow = tableData[indexPath.section][indexPath.row]
        selectRow(tableRow)
    }

    func selectRow(_ tableRow: TableRow) {
        switch tableRow {
        case .general:
            navigationController?.pushViewController(GeneralSettingsViewController(), animated: true)
        case .notifications:
            navigationController?.pushViewController(NotificationsViewController(), animated: true)
        case .appearance:
            navigationController?.pushViewController(AppearanceViewController(), animated: true)
        case .storageAndDataUse:
            navigationController?.pushViewController(StorageAndDataUseViewController(), animated: true)
        case .autoAddToUpNext:
            navigationController?.pushViewController(AutoAddToUpNextViewController(), animated: true)
        case .autoArchive:
            navigationController?.pushViewController(AutoArchiveViewController(), animated: true)
        case .autoDownload:
            navigationController?.pushViewController(DownloadSettingsViewController(), animated: true)
        case .importSteps:
            let types = [UTType.xml, UTType("public.opml"), UTType("unofficial.opml")].compactMap { $0 }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.delegate = self
            navigationController?.present(picker, animated: true)
        case .opml:
            navigationController?.pushViewController(ImportExportViewController(), animated: true)
        case .about:

            let aboutView = AboutView()
                .environmentObject(Theme.shared)
            let hostingController = PCHostingController(rootView: aboutView)

            navigationController?.present(hostingController, animated: true, completion: nil)
        case .siriShortcuts:
            navigationController?.pushViewController(SiriSettingsViewController(), animated: true)
        case .customFiles:
            navigationController?.pushViewController(UploadedSettingsViewController(), animated: true)
        case .beta:
            let hostingController = UIHostingController(rootView: BetaMenu().setupDefaultEnvironment())
            hostingController.title = "Beta Features"
            navigationController?.pushViewController(hostingController, animated: true)
        case .headphoneControls:
            navigationController?.pushViewController(HeadphoneSettingsViewController(), animated: true)
        case .upNextHistory:
            let upNextHistory = UpNextHistoryViewController()
            navigationController?.pushViewController(upNextHistory, animated: true)
        case .troubleshooting:
            navigationController?.pushViewController(ThemedHostingController(rootView: TroubleshootingView()), animated: true)
        case .logs:
            navigationController?.pushViewController(LogsViewController(), animated: true)
        case .exportDatabase:
            exportDatabase()
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        1
    }

    private func reloadTable() {
        tableData = allSections

        settingsTable.reloadData()
    }
}

// MARK: - Database export

private extension SettingsViewController {
    func exportDatabase() {
        databaseExport = DatabaseExport()

        loadingAlert = ShiftyLoadingAlert(title: L10n.exportingDatabase)
        loadingAlert?.showAlert(self, hasProgress: false, completion: { [weak self] in
            Task {
                let url = await self?.databaseExport?.export()
                self?.shareExport(url: url)
            }
        })
    }

    @MainActor
    func shareExport(url: URL?) {
        loadingAlert?.hideAlert(false)
        loadingAlert = nil

        guard let url else {
            databaseExport = nil
            SJUIUtils.showAlert(title: L10n.settingsExportError, message: nil, from: self)
            return
        }

        let shareSheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        shareSheet.completionWithItemsHandler = { [weak self] _, _, _, _ in
            // Remove the temporary export once the share sheet is done with it
            self?.databaseExport?.cleanup(url: url)
            self?.databaseExport = nil
        }

        if let popover = shareSheet.popoverPresentationController,
           let section = tableData.firstIndex(where: { $0.contains(.exportDatabase) }),
           let row = tableData[section].firstIndex(of: .exportDatabase) {
            popover.sourceView = settingsTable
            popover.sourceRect = settingsTable.rectForRow(at: IndexPath(row: row, section: section))
        }

        present(shareSheet, animated: true, completion: nil)
    }
}

// MARK: - OPML import

extension SettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        _ = appDelegate.handleOpenUrl(url: url, rootViewController: self)
    }
}
