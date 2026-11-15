import PocketCastsUtils
import UIKit

@MainActor
enum SceneHelper {
    static func connectedScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap {
            $0 as? UIWindowScene
        }.first
    }

    static func rootViewController(includeTopMost: Bool = true) -> UIViewController? {
        let appScene = connectedScene()?.windows.first(where: { $0.rootViewController is MainTabBarController })
        let rootVC = appScene?.rootViewController
        if includeTopMost {
            return rootVC?.topMostPresentedViewController ?? rootVC
        }
        return rootVC
    }
}
