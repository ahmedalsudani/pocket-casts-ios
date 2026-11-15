import SwiftUI

/// Adds a subtle parallax effect to the app icon as the user tilts their device
struct IconParallaxModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject var manager: MotionManager = .init()

    func body(content: Content) -> some View {
        let roll = manager.roll * 10
        let pitch = manager.pitch
        content
            .offset(x: roll, y: pitch * 10)
            .rotation3DEffect(.degrees(roll), axis: (0, 1, 0), perspective: 1)
            .rotation3DEffect(.degrees(pitch * 3), axis: (1, 0, 0), perspective: 1)
            .onAppear() {
                if !reduceMotion {
                    manager.start()
                }
            }
            .onDisappear() {
                if !reduceMotion {
                    manager.stop()
                }
            }
    }
}
