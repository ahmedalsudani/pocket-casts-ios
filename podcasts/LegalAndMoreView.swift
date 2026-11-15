import SwiftUI
import WebKit

struct LegalAndMoreView: View {
    @EnvironmentObject var theme: Theme

    @Binding var navigationPath: [AboutNavigationPathComponent]

    var body: some View {
        ZStack {
            ThemeColor.primaryUi04(for: theme.activeTheme).color
                .ignoresSafeArea()
            List {
                Section {
                    AboutRow(mainText: L10n.aboutAcknowledgements, showChevronIcon: true) {
                        navigationPath.append(.acknowledgements)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .colorScheme(theme.activeTheme.isDark ? .dark : .light)
            .scrollContentBackground(.hidden)
        }
        .navigationBarTitle(L10n.aboutLegalAndMore, displayMode: .inline)
    }

    enum Constants {
        static let acknowledgementsURL = Bundle.main.url(forResource: "acknowledgements", withExtension: "html")!
    }
}

struct WebView: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
