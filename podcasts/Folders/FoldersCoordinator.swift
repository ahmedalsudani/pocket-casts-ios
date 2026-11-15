import UIKit
import SwiftUI
import PocketCastsDataModel

class FoldersCoordinator: NSObject {
    private let navigationManager: NavigationManager
    private let dataManager: DataManager

    init(navigationManager: NavigationManager = .shared, dataManager: DataManager = .shared) {
        self.navigationManager = navigationManager
        self.dataManager = dataManager
        super.init()
    }

    func startFolderCreationFlow(from vc: UIViewController) {
        let creatFolderView = CreateFolderView { [weak vc, weak self] folderUuid in
            guard let self else { return }
            if let folderUuid, let folder = dataManager.findFolder(uuid: folderUuid) {
                vc?.dismiss(animated: true, completion: { [weak self] in
                    self?.navigationManager.navigateTo(NavigationManager.folderPageKey, data: [NavigationManager.folderKey: folder])
                })
            } else {
                vc?.dismiss(animated: true, completion: nil)
            }
        }
        let hostingController = PCHostingController(rootView: creatFolderView.environmentObject(Theme.shared))

        vc.present(hostingController, animated: true, completion: nil)
    }
}
