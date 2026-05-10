import Foundation
import PocketCastsDataModel
import PocketCastsServer

class OpmlImporter: Operation, XMLParserDelegate {
    private let opmlFileUrl: URL
    private let progressWindow: ShiftyLoadingAlert?

    private var parsedUrls = [String]()
    private var initialPodcastCount = 0
    private var importedCount = 0

    private lazy var importQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 5
        return queue
    }()

    init(opmlFile: URL, progressWindow: ShiftyLoadingAlert? = nil) {
        opmlFileUrl = opmlFile
        self.progressWindow = progressWindow

        super.init()
    }

    override func main() {
        autoreleasepool {
            Analytics.track(.opmlImportStarted)

            let parser = XMLParser(contentsOf: opmlFileUrl)
            parser?.delegate = self
            guard let parsed = parser?.parse(), parsed, !parsedUrls.isEmpty else {
                DispatchQueue.main.sync {
                    if let progressWindow = self.progressWindow {
                        progressWindow.hideAlert(false)
                        let controller = SceneHelper.rootViewController()

                        SJUIUtils.showAlert(title: L10n.opmlImportFailedTitle, message: L10n.opmlImportFailedMessage, from: controller)
                    } else {
                        NotificationCenter.postOnMainThread(notification: Constants.Notifications.opmlImportFailed)
                    }

                    Analytics.track(.opmlImportFailed)
                }

                return
            }

            initialPodcastCount = parsedUrls.count
            importAllPodcasts()

            DispatchQueue.main.async {
                if let progressWindow = self.progressWindow {
                    NavigationManager.sharedManager.navigateTo(NavigationManager.podcastListPageKey, data: nil)
                    progressWindow.hideAlert(true)
                }

                NotificationCenter.postOnMainThread(notification: Constants.Notifications.opmlImportCompleted)

                Analytics.track(.opmlImportFinished, properties: ["count": self.initialPodcastCount, "number_parsed": self.importedCount])
            }
        }
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        guard elementName.lowercased() == "outline", let url = attributeDict["xmlUrl"] else { return }

        let trimmedURL = url.trim()
        guard !trimmedURL.isEmpty else { return }

        parsedUrls.append(trimmedURL)
    }

    // MARK: - Add Podcasts

    private func importAllPodcasts() {
        for urlString in parsedUrls {
            guard let url = URL(string: urlString) else {
                self.importedCount += 1
                continue
            }

            importQueue.addOperation {
                let group = DispatchGroup()
                group.enter()
                ServerPodcastManager.shared.addFromFeedURL(url, subscribe: true, autoDownloads: 0) { _, _ in
                    self.importedCount += 1

                    DispatchQueue.main.async {
                        guard let progressWindow = self.progressWindow else { return }
                        progressWindow.title = self.progress(imported: self.importedCount, total: self.initialPodcastCount)
                    }
                    group.leave()
                }
                _ = group.wait(timeout: .now() + 30.seconds)
            }
        }

        importQueue.waitUntilAllOperationsAreFinished()
    }

    func progress(imported: Int, total: Int) -> String {
        L10n.opmlImportProgressFormat(imported.localized(), total.localized())
    }
}
