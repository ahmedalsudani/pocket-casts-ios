import SwiftUI

/// The root of the app: the menu of what's on the phone.
struct MainNavigationView: View {
    var body: some View {
        NavigationStack {
            InterfaceView()
        }
        .environmentObject(NavigationManager.shared)
    }
}

#Preview {
    MainNavigationView()
}
