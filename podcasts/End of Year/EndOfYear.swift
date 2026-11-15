import SwiftUI
import PocketCastsServer
import PocketCastsDataModel
import EndOfYear
import PocketCastsUtils

struct EndOfYear {
    enum Year: CaseIterable {
        case y2022
        case y2023
        case y2024
        case y2025

        var modelType: StoryModel.Type? {
            switch self {
            case .y2022:
                nil
            case .y2023:
                EndOfYear2023StoriesModel.self
            case .y2024:
                EndOfYear2024StoriesModel.self
            case .y2025:
                EndOfYear2025StoriesModel.self
            }
        }

        var year: Int? {
            modelType?.year
        }
    }

    static var isEligible: Bool { eligibilityChecker?.isEligible ?? false }

    static var isEndOfYearActive: Bool {
        if FeatureFlag.endOfYear2025.enabled || FeatureFlag.endOfYear2024.enabled || FeatureFlag.endOfYear.enabled {
            return true
        }
        return false
    }

    // Eligibility checker to manage the `isEligible` state
    private static var eligibilityChecker: EligibilityChecker? = {
        if let year = currentYear.year {
            .init(year: year)
        } else {
            nil
        }
    }()

    static var currentYear: Year {
        if FeatureFlag.endOfYear2025.enabled {
            return .y2025
        } else if FeatureFlag.endOfYear2024.enabled {
            return .y2024
        } else if FeatureFlag.endOfYear.enabled {
            return .y2023
        } else {
            return .y2022
        }
    }

    private(set) var storyModelType: StoryModel.Type?

    func presentationMode(for traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular ? .formSheet : .fullScreen
    }

    func storiesPadding(for presentationMode: UIModalPresentationStyle) -> EdgeInsets {
        .init(top: 0, leading: 0, bottom: presentationMode == .formSheet ? 5 : 0, trailing: 0)
    }

    init() {
        storyModelType = Self.currentYear.modelType
    }

    func showPrompt(in viewController: UIViewController) {
        guard Self.isEndOfYearActive,
              Self.isEligible,
              let storyModelType,
              viewController.presentedViewController == nil,
              !Settings.hasShownModalForEndOfYear(storyModelType.year)
        else {
            return
        }

        let viewModel: EndOfYearModal.ViewModel

        switch Self.currentYear {
        case .y2022:
        #if DEBUG
            assertionFailure("Shouldn't reach this")
        #endif
            return
        case .y2023:
            viewModel = .init(buttonTitle: L10n.eoyViewYear, description: L10n.eoyDescription, backgroundImageName: "modal_cover")
        case .y2024:
            viewModel = .init(buttonTitle: L10n.playback2024ViewYear, description: L10n.playback2024Description, backgroundImageName: "playback-featured")
        case .y2025:
            viewModel = .init(buttonTitle: L10n.playback2025ViewYear, description: L10n.playback2025Description, backgroundImageName: "playback-2025-featured")
        }

        BottomSheetSwiftUIWrapper.present(EndOfYearModal(year: storyModelType.year, model: viewModel), autoSize: true, in: viewController)
        Settings.setHasShownModalForEndOfYear(true, year: storyModelType.year)
    }

    func showPromptBasedOnState(in viewController: UIViewController) {
        showPrompt(in: viewController)
    }

    var configuration: StoriesConfiguration {
        let configuration = StoriesConfiguration()
        if EndOfYear.currentYear == .y2025 {
            configuration.closeAndDismissAfterFinished = true
            configuration.loadingIsTheFirstStory = FeatureFlag.endOfYearLoadIsFirstStory.enabled
            configuration.defaultStoriesCount = 11
        }
        return configuration
    }

    func showStories(in viewController: UIViewController) {
        guard let storyModelType else { return }

        // Don't show the prompt if the user is has already viewed the stories.
        Settings.setHasShownModalForEndOfYear(true, year: storyModelType.year)

        let model = storyModelType.init()
        let modalPresentationStyle = presentationMode(for: viewController.traitCollection)

        let storiesViewController = StoriesHostingController(rootView: StoriesView(dataSource: EndOfYearStoriesDataSource(model: model), configuration: configuration).padding(storiesPadding(for: modalPresentationStyle)))
        storiesViewController.view.backgroundColor = .black
        storiesViewController.modalPresentationStyle = modalPresentationStyle

        // Define the size of the stories view for iPad
        if modalPresentationStyle == .formSheet {
            storiesViewController.preferredContentSize = .init(width: 370, height: 693)
        }

        viewController.present(storiesViewController, animated: true, completion: nil)
    }

    @MainActor
    static func share(assets: [Any], model: StoriesModel, onDismiss: (() -> Void)? = nil) {
        let presenter = SceneHelper.rootViewController()

        let fakeViewController = FakeViewController()
        fakeViewController.onDismiss = onDismiss
        fakeViewController.modalPresentationStyle = .overFullScreen

        let activityViewController = UIActivityViewController(activityItems: assets, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = presenter?.view

        activityViewController.completionWithItemsHandler = { activity, success, _, _ in
            if !success && activity == nil {
                fakeViewController.dismiss(animated: false)
            }

            if activity != nil, success {
                DispatchQueue.main.async {
                    fakeViewController.dismiss(animated: false)
                }
            }
        }

        // Present the fake view controller first to avoid issues with stories being dismissed
        presenter?.present(fakeViewController, animated: false) { [weak fakeViewController] in
            // Present the share sheet
            fakeViewController?.present(activityViewController, animated: true) {
                // After the share sheet is presented we take the snapshot
                // This action needs to happen on the main thread because
                // the view needs to be rendered.
                StoryShareableProvider.shared.snapshot(viewModifier: model.sharingSnapshotModifier)
            }
        }
    }

}

extension EndOfYear {
    static var defaultDuration: TimeInterval {
        switch currentYear {
        case .y2025: return 7.seconds
        case .y2024: return 10.seconds
        default: return 7.seconds
        }
    }
}

class StoriesHostingController<ContentView: View>: UIHostingController<ContentView> {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        switch EndOfYear.currentYear {
        case .y2025: return .default
        case .y2024: return .darkContent
        default: return .lightContent
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Dark overlay background for iPad
        presentationController?.containerView?.backgroundColor = .black.withAlphaComponent(0.8)
    }
}

/// When selecting "Save Image" on the share sheet on iOS 15
/// the sheets dismisses itself AND the stories.
/// We don't want that, so we have this fake view controller to
/// be dismissed instead.
///
/// The issue doesn't affect iOS 14 and 16, but given this fix
/// don't interfere with them, we also use it for 14/16.
private class FakeViewController: UIViewController {
    var onDismiss: (() -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onDismiss?()
    }
}

extension EndOfYear {
    static let eoyEligibilityDidChange = NSNotification.Name(rawValue: "eoyEligibilityDidChange")

    private class EligibilityChecker {
        deinit {
            stopListening()
        }

        var isEligible = false

        private let notificationCenter: NotificationCenter
        private var notifications: [NSObjectProtocol] = []

        private let year: Int

        init(year: Int, notificationCenter: NotificationCenter = .default) {
            self.year = year

            self.notificationCenter = notificationCenter

            startListening()
            update()
        }

        private func startListening() {
            // The notifications to update the state for
            let notifications: [Notification.Name] = [
                // Check as the user is listening to episodes
                Constants.Notifications.playbackPaused,
                Constants.Notifications.playbackEnded,
                Constants.Notifications.playbackTrackChanged
            ]

            self.notifications = notifications.map {
                notificationCenter.addObserver(forName: $0, object: nil, queue: .main) { [weak self] _ in
                    self?.update()
                }
            }
        }

        private func stopListening() {
            notifications.forEach { notificationCenter.removeObserver($0) }
            notifications.removeAll()
        }

        private func update() {
            isEligible = DataManager.shared.isEligibleForEndOfYearStories(in: year)

            // Let others know this changed
            if isEligible {
                notificationCenter.post(name: EndOfYear.eoyEligibilityDidChange, object: nil)

                // We don't need to check eligibility anymore
                stopListening()
            }
        }
    }
}
