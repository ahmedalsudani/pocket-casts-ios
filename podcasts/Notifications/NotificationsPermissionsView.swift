import SwiftUI
import PocketCastsUtils

class NotificationsPermissionsViewModel: ObservableObject {
    @Published var notificationsOptIn: Bool = true

    func setupPermissions() async {
        let coordinator = NotificationsCoordinator.shared
        await coordinator.requestAndSetupInitialPermissions()
    }

    enum NotificationOption: CaseIterable {
        case notifications

        var title: String {
            switch self {
            case .notifications:
                return L10n.notificationsOnboardingNotificationsTitle
            }
        }

        var subtitle: String {
            switch self {
            case .notifications:
                return L10n.notificationsOnboardingNotificationsSubtitle
            }
        }

        func isSelected(_ viewModel: NotificationsPermissionsViewModel) -> Bool {
            switch self {
            case .notifications:
                return viewModel.notificationsOptIn
            }
        }

        func toggle(_ viewModel: NotificationsPermissionsViewModel) {
            switch self {
            case .notifications:
                viewModel.notificationsOptIn.toggle()
            }
        }
    }

    static func makeController() -> UIViewController {
        let viewModel = NotificationsPermissionsViewModel()

        let view = NotificationsPermissionsView(viewModel: viewModel)
        let controller = UIHostingController(rootView: view.setupDefaultEnvironment())

        return  controller
    }
}

struct NotificationsPermissionsView: View {

    @Environment(\.dismiss) private var dismissAction

    @EnvironmentObject var theme: Theme

    @StateObject var viewModel = NotificationsPermissionsViewModel()

    @ViewBuilder
    private func optionRow(for option: NotificationsPermissionsViewModel.NotificationOption) -> some View {
        Button {
            option.toggle(viewModel)
        } label: {
            HStack(spacing: 17) {
                Button {
                    option.toggle(viewModel)
                } label: {
                    EmptyView() // content is provided by the style
                }
                .buttonStyle(
                    SelectCircleButtonStyle(selected: .constant(option.isSelected(viewModel)))
                )
                .environmentObject(Theme.shared)
                .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text(option.title)
                        .font(style: .subheadline, weight: .medium)
                        .foregroundStyle(theme.primaryText01)
                    Text(option.subtitle)
                        .font(.footnote)
                        .foregroundStyle(theme.primaryText02)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(option.isSelected(viewModel) ? .isSelected : [])
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(maxHeight: 136)
                    ViewThatFits(in: .vertical) {
                        Image("notifications_permissions_banner")
                        Image("notifications_permissions_banner")
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(maxHeight: proxy.size.height * 0.42)
                    Spacer().frame(height: 24)
                    Text(L10n.notificationsPermissionsTitle)
                        .textStyle(PrimaryText())
                        .font(.largeTitle.bold())
                    Spacer().frame(height: 20)
                    Text(L10n.notificationsPermissionsBody)
                        .textStyle(SecondaryText())
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    VStack(alignment: .leading, spacing: 24) {
                        optionRow(for: .notifications)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 34)
                    .padding(.horizontal, 4)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ZStack {
                Button(action: {
                    Task {
                        if viewModel.notificationsOptIn {
                            await viewModel.setupPermissions()
                        }
                        dismissAction()
                    }
                }) {
                    Text(L10n.notificationsPermissionsSavePreferences)
                        .textStyle(RoundedButton())
                }
            }
            .padding(16)
            .background(
                LinearGradient(gradient: Gradient(stops: [
                    Gradient.Stop(color: theme.primaryUi01.opacity(0.0), location: 0.0),
                    Gradient.Stop(color: theme.primaryUi01, location: 0.1),
                ]), startPoint: .top, endPoint: .bottom)
            )
        }
        .background(theme.primaryUi01)
    }
}

struct NotificationsPermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsPermissionsView()
            .environmentObject(Theme(previewTheme: .light))
    }
}
