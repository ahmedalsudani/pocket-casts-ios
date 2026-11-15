import UIKit
import PocketCastsDataModel
import EndOfYear

class StoryShareableText: UIActivityItemProvider, ShareableMetadataDataSource, @unchecked Sendable {
    private var text: String

    private var longURL: String?

    var shareableMetadataProvider = ShareableMetadataProvider()

    private var year: EndOfYear.Year

    var hashtags: [String] {
        var hashtags = [String]()
        if let year = year.year {
            hashtags.append("playback\(year)")
        }
        return hashtags
    }

    var shareableLink: String {
        longURL ?? ""
    }

    init(_ text: String, year: EndOfYear.Year) {
        self.text = text
        self.year = year
        super.init(placeholderItem: self.text)
    }

    init(_ text: String, podcast: Podcast, year: EndOfYear.Year) {
        self.text = text
        self.year = year
        super.init(placeholderItem: self.text)
        self.longURL = podcast.shareURL
    }

    init(_ text: String, episode: Episode, year: EndOfYear.Year) {
        self.text = text
        self.year = year
        super.init(placeholderItem: self.text)
        self.longURL = episode.shareURL
    }

    init(_ text: String, podcasts: [Podcast], year: EndOfYear.Year) {
        self.text = text
        self.year = year
        super.init(placeholderItem: self.text)
    }

    override func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        shareableMetadataProvider.dataSource = self

        // Facebook ignores text, so we only share the image
        // WhatsApp ignore the image if we share text, so we also share just the image
        if activityType == .postToFacebook ||
            activityType?.rawValue.contains("whatsapp") == true ||
            activityType?.rawValue.contains("instagram") == true {
            return nil
        }

        let supportsMetadata = activityType?.supportsShareableMetadata ?? false
        let showHashTags = activityType != .message && !supportsMetadata

        let text = shareableText(showLinks: !supportsMetadata, showHashTags: showHashTags).trim()

        // Remove any empty text to prevent gaps
        guard !text.isEmpty else { return nil }
        guard supportsMetadata else { return text }

        // Show the text as a title when sharing to a metadata network such as Tumblr
        let item = NSExtensionItem()
        item.attributedTitle = NSAttributedString(string: text)
        return item
    }

    private func shareableText(showLinks: Bool, showHashTags: Bool) -> String {
        var text = self.text

        // For Messages we don't want to add hashtags
        if showHashTags {
            let tags = hashtags.map { "#" + $0 }.joined(separator: " ")
            text = "\(text) \(tags)".trim()
        }

        if let longURL {
            return String(format: text, showLinks ? longURL : "")
        }

        // The top podcasts text has a slot for a link to the list, which there is nowhere to publish
        return String(format: text, "").trim()
    }
}
