#if !os(watchOS)
    import UIKit

    public extension UILabel {
        func setLetterSpacing(_ letterSpacing: CGFloat) {
            guard let text else { return }
            let attributedString = NSMutableAttributedString(string: text)
            attributedString.addAttribute(NSAttributedString.Key.kern, value: letterSpacing, range: NSRange(location: 0, length: text.count))
            attributedText = attributedString
        }

        func updateNumberOfLines(regular: Int, accessibility: Int) {
            self.numberOfLines = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? accessibility : regular
        }
    }
#endif
