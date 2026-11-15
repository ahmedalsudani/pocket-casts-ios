import Foundation

class LogsViewController: ThemedHostingController<LogsView> {
    init() {
        super.init(rootView: LogsView(model: LogsViewModel()))
    }

    @MainActor dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}
