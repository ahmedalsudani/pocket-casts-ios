import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
#if !os(watchOS)
import AuthenticationServices
#endif

/// The Pocket Casts account / sync subsystem has been removed. All login
/// entry points throw `loginDisabled` so the onboarding UI surfaces an
/// error instead of attempting to talk to `api.pocketcasts.com`.
class AuthenticationHelper {

    enum AuthenticationError: Error {
        case loginDisabled
    }

    @discardableResult
    static func refreshLogin(scope: AuthenticationScope = .mobile) async throws -> String? {
        nil
    }

    static func validateLogin(username: String, password: String, scope: AuthenticationScope) async throws -> AuthenticationResponse {
        throw AuthenticationError.loginDisabled
    }

    static func validateLogin(identityToken: String, scope: AuthenticationScope = .mobile) async throws -> AuthenticationResponse {
        throw AuthenticationError.loginDisabled
    }

    static func validateLogin(identityToken: String, provider: SocialAuthProvider) async throws -> AuthenticationResponse {
        throw AuthenticationError.loginDisabled
    }
}
