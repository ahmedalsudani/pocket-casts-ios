import Foundation
import PocketCastsUtils

/// Telemetry has been removed. This shim keeps the `Analytics.track(...)`
/// surface so call sites compile, but every call is a no-op. The
/// `AnalyticsAdapter` / `AnalyticsDescribable` protocols stay because
/// peripheral types still conform to them.
class Analytics {
    static let shared = Analytics()

    var adaptersRegistered: Bool = false

    static func register(adapters: [AnalyticsAdapter]) {}

    static func unregister() {}

#if !os(watchOS) && !APPCLIP && !os(tvOS)
    var analyticsAppThemeProvider: AnalyticsAppThemeProviding?

    static func add(analyticsAppThemeProvider: AnalyticsAppThemeProviding) {}
#endif

    static func track(_ event: AnalyticsEvent, properties: [AnyHashable: Any]? = nil) {}

    func track(_ event: AnalyticsEvent, properties: [AnyHashable: Any]? = nil) {}
}

// MARK: - Analytics + Source

extension Analytics {
    static func track(_ event: AnalyticsEvent, source: Any, properties: [AnyHashable: Any]? = nil) {}
}

// MARK: - Opt out/in

extension Analytics {
    func optOutOfAnalytics() {
        Settings.setAnalytics(optOut: true)
    }

    func optInOfAnalytics() {
        Settings.setAnalytics(optOut: false)
    }

    func refreshRegistered() {}
}

// MARK: - Protocols

/// Allows an object to determine how its described in the context of analytics
protocol AnalyticsDescribable {
    var analyticsDescription: String { get }
}

/// Classes can implement this to determine their own logic on how to handle each event
protocol AnalyticsAdapter {
    var isThirdPartyAdapter: Bool { get }
    func track(name: String, properties: [AnyHashable: Any]?)
}

extension AnalyticsAdapter {
    var isThirdPartyAdapter: Bool {
        false
    }
}

// MARK: - Dynamic Event Name

extension AnalyticsEvent {
    var eventName: String {
        return rawValue.toSnakeCaseFromCamelCase()
    }
}
