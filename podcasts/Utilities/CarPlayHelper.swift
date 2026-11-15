import CarPlay

enum CarPlayHelper {
    static var isConnectedToCarPlay: Bool {
        UIApplication.shared.connectedScenes.contains(where: {
            $0 is CPTemplateApplicationScene
        })
    }
}
