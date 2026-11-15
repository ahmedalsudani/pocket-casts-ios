import UIKit

class UploadedSettingsViewController: PCViewController, UITableViewDelegate, UITableViewDataSource {
    private let switchCellId = "SwitchCell"
    private enum TableSections: Int, CaseIterable { case autoAddToUpNext, afterPlaying }

    @IBOutlet var settingsTable: UITableView! {
        didSet {
            settingsTable.register(UINib(nibName: "SwitchCell", bundle: nil), forCellReuseIdentifier: switchCellId)

            settingsTable.rowHeight = UITableView.automaticDimension
            settingsTable.estimatedRowHeight = UITableView.automaticDimension
            settingsTable.sectionHeaderHeight = UITableView.automaticDimension
            settingsTable.estimatedSectionHeaderHeight = Constants.Values.tableSectionHeaderHeight
            settingsTable.sectionFooterHeight = UITableView.automaticDimension
            settingsTable.estimatedSectionFooterHeight = Constants.Values.tableSectionHeaderHeight
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        AppTheme.defaultStatusBarStyle()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.settingsFiles
        insetAdjuster.setupInsetAdjustmentsForMiniPlayer(scrollView: settingsTable)
    }

    // MARK: - UITableView Methods

    func numberOfSections(in tableView: UITableView) -> Int {
        TableSections.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: switchCellId, for: indexPath) as! SwitchCell
        cell.cellSwitch.removeTarget(self, action: nil, for: UIControl.Event.valueChanged)

        switch TableSections.allCases[indexPath.section] {
        case .autoAddToUpNext:
            cell.cellLabel?.text = L10n.settingsAutoAdd
            cell.setImage(imageName: "settings_upnext")
            cell.cellSwitch.isOn = Settings.userEpisodeAutoAddToUpNext
            cell.cellSwitch.addTarget(self, action: #selector(autoAddToUpNextToggled(_:)), for: .valueChanged)
        case .afterPlaying:
            cell.cellLabel?.text = L10n.settingsFilesDeleteLocalFile
            cell.setImage(imageName: "delete")
            cell.cellSwitch.isOn = Settings.userEpisodeRemoveFileAfterPlaying
            cell.cellSwitch.addTarget(self, action: #selector(removeFileAfterPlayingToggled(_:)), for: .valueChanged)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch TableSections.allCases[section] {
        case .autoAddToUpNext:
            return L10n.settingsFilesAddUpNextSubtitle
        case .afterPlaying:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        ThemeableTable.setHeaderFooterTextColor(on: view)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerFrame = CGRect(x: 0, y: 0, width: 0, height: Constants.Values.tableSectionHeaderHeight)
        let title: String
        switch TableSections.allCases[section] {
        case .autoAddToUpNext:
            title = ""
        case .afterPlaying:
            title = L10n.afterPlaying.localizedUppercase
        }

        return SettingsTableHeader(frame: headerFrame, title: title)
    }

    // MARK: - Switch Actions

    @objc private func autoAddToUpNextToggled(_ sender: UISwitch) {
        Settings.userEpisodeAutoAddToUpNext = sender.isOn
    }

    @objc private func removeFileAfterPlayingToggled(_ sender: UISwitch) {
        Settings.userEpisodeRemoveFileAfterPlaying = sender.isOn
    }
}
