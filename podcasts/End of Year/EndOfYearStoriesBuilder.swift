import Foundation
import PocketCastsDataModel
import PocketCastsServer
import SwiftUI

/// Build the list of stories for End of Year alongside the data
class EndOfYearStoriesBuilder {
    private let dataManager: DataManager

    private var model: StoryModel

    init(dataManager: DataManager = DataManager.shared, model: StoryModel) {
        self.dataManager = dataManager
        self.model = model
    }

    /// Call this method to build the list of stories and the data provider.
    /// The stories are made from the listening history held on this device.
    func build() async {
        model.populate(with: dataManager)
    }
}

protocol StoryModel {
    init()
    static var year: Int { get }
    var numberOfStories: Int { get }
    func populate(with dataManager: DataManager)
    func story(for storyNumber: Int) -> any StoryView
    func isInteractiveView(for storyNumber: Int) -> Bool
    func isReady() -> Bool
    /// Overlaid on top of the story
    func overlaidShareView() -> AnyView?
    /// Shown at the bottom of the story as an additional safe area
    func footerShareView() -> AnyView?
    func indicatorColor(for storyNumber: Int) -> Color
    var primaryBackgroundColor: Color { get }
    func sharingSnapshotModifier(_ view: AnyView) -> AnyView
}
