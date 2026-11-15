import SwiftUI
import SafariServices

struct UnderlineLinkTextView: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        var attributedString = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        attributedString.runs.filter({ $0.link != nil }).forEach({ run in
            attributedString[run.range].underlineStyle = .init(pattern: .solid)
        })
        let textView = Text(attributedString)

        // Open the link inside the app
        return textView.environment(\.openURL, OpenURLAction { url in
            let safariViewController = SFSafariViewController(with: url)
            safariViewController.modalPresentationStyle = .formSheet
            SceneHelper.rootViewController()?.present(safariViewController, animated: true, completion: nil)
            return .handled
        })
    }
}

#Preview {
    VStack {
        UnderlineLinkTextView("Hello **World**!")
        UnderlineLinkTextView("Hel[lo, Wor](https://example.com)ld!")
        UnderlineLinkTextView("[Hello](https://example.com), World!")
        UnderlineLinkTextView("Hello, [World](https://example.com)!")
        UnderlineLinkTextView("I have [multiple](https://example.com) [links](https://example.com)!")
        UnderlineLinkTextView("Look [how](https://example.com) cool [I](https://example.com) [am](https://example.com)! :)")
    }
}
