import Foundation

class AboutViewModel: ObservableObject {
    @Published var navigationPath: [AboutNavigationPathComponent] = []
}

enum AboutNavigationPathComponent {
    case legalAndMore
    case acknowledgements
}
