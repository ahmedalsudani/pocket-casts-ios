import Foundation
import SwiftUI

/// View model for the header view that appears on the Profile tab view
class ProfileHeaderViewModel: ProfileDataViewModel {
    weak var navigationController: UINavigationController? = nil

    init(navigationController: UINavigationController? = nil) {
        super.init()

        self.navigationController = navigationController
    }
}
