import Foundation

extension String {
    /// The string led by the symbol for the phone, which is where everything shown comes from
    var prefixSourceUnicode: String {
        L10n.phone.sourceUnicode() + " \(self)"
    }

    func sourceUnicode() -> String {
        let fallback = "🅿"
        let uppercaseSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        guard let firstChar = first,
              let latinFirstCharacter = NSString(string: "\(firstChar)")
              .applyingTransform(.toLatin, reverse: false)?
              .applyingTransform(.stripDiacritics, reverse: false)?
              .capitalized,
              let unicodeScaler = UnicodeScalar(latinFirstCharacter),
              uppercaseSet.contains(unicodeScaler) // Final Check to make sure the character was successfully converted.
        else { return fallback }

        // Square Unicode character 🅰
        let offset = unicodeScaler.value - UnicodeScalar("A").value
        guard let negativeSpaceCharacter = UnicodeScalar(UnicodeScalar("\u{1F170}").value + offset) else { return fallback }

        return String(String.UnicodeScalarView([negativeSpaceCharacter]))
    }
}
