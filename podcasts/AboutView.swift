import SwiftUI

struct AboutView: View {
    @EnvironmentObject var theme: Theme

    @StateObject private var model = AboutViewModel()

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack(path: $model.navigationPath) {
            ZStack {
                ThemeColor.primaryUi04(for: theme.activeTheme).color
                    .ignoresSafeArea()
                Form {
                    form
                }
                .colorScheme(theme.activeTheme.isDark ? .dark : .light)
                .scrollContentBackground(.hidden)
            }
            .navigationDestination(for: AboutNavigationPathComponent.self) {
                switch $0 {
                case .legalAndMore:
                    LegalAndMoreView(navigationPath: $model.navigationPath)
                case .acknowledgements:
                    WebView(url: LegalAndMoreView.Constants.acknowledgementsURL)
                        .navigationTitle(L10n.aboutAcknowledgements)
                        .ignoresSafeArea()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button.make(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var form: some View {
        VStack {
            Image(AppTheme.pcLogoVerticalImageName())
                .accessibilityHidden(true)
            Text(Settings.displayableVersion())
                .font(.subheadline)
                .textStyle(SecondaryText())
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)

        Section {
            AboutRow(mainText: L10n.aboutLegalAndMore, showChevronIcon: true) {
                model.navigationPath = [.legalAndMore]
            }
        }

        Section {
            HStack {
                Spacer()
                Image("automattic-logo")
                    .tint(theme.activeTheme.isDark ? .white : .black)
                Spacer()
            }
        }
        .listRowBackground(Color.clear)
    }
}

struct AboutRow: View {
    @EnvironmentObject var theme: Theme

    @State var mainText = ""
    @State var showChevronIcon: Bool = false
    @State var action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            HStack {
                Text(mainText)
                    .textStyle(PrimaryText())
                Spacer()
                if showChevronIcon {
                    Image("chevron")
                        .renderingMode(.template)
                        .foregroundColor(ThemeColor.primaryIcon02(for: theme.activeTheme).color)
                }
            }
        }
        .listRowBackground(ThemeColor.primaryUi02(for: theme.activeTheme).color)
    }
}

// MARK: Previews

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
            .environmentObject(Theme(previewTheme: .dark))
    }
}
