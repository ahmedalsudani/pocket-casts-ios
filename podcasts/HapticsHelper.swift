import Foundation
import UIKit

enum HapticsHelper {
    static func triggerSkipBackHaptic() {
        triggerImpactOccurredHaptic(style: .medium)
    }

    static func triggerSkipForwardHaptic() {
        triggerImpactOccurredHaptic(style: .medium)
    }

    static func triggerSubscribedHaptic() {
        triggerSuccessHaptic()
    }

    static func triggerPlayPauseHaptic() {
        triggerImpactOccurredHaptic(style: .light)
    }

    private static func triggerImpactOccurredHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: style)
        feedbackGenerator.impactOccurred()
    }

    private static func triggerSuccessHaptic() {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.success)
    }

    static func triggerErrorHaptic() {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.error)
    }
}
