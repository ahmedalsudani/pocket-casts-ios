import SwiftUI

struct StoryFooter2025: View {
    let title: String?
    let description: String?

    init(title: String? = nil, description: String? = nil) {
        self.title = title
        self.description = description
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack { Spacer() }
            if let title {
                Text(title)
                    .font(.system(size: 31, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            if let description {
                Text(description)
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}
