import XCTest

enum Config {
    /// Feeds of the podcasts the screenshots show
    static let podcastFeeds = [
        "https://feeds.simplecast.com/PpzWFGhg", // Serial
        "https://relay.fm/connected/feed", // Connected
        "https://www.abc.net.au/feeds/2888650/podcast.xml", // All In The Mind
        "https://distributed.blog/category/podcast/feed/", // Distributed, with Matt Mullenweg
        "https://feeds.megaphone.fm/vergecast", // The Vergecast
        "https://www.abc.net.au/feeds/12801214/podcast.xml", // Download This Show
        "https://feeds.simplecast.com/93bEBtXA", // American Fiasco
        "https://making.podcasts.wbez.org" // Making
    ]
}

class GenerateScreenshots: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    enum Tab: Int {
        case podcasts = 0
        case filters
        case discover
        case profile
    }

    let app = XCUIApplication()
    lazy var safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")

    override func setUpWithError() throws {
        continueAfterFailure = false
        setupSnapshot(app)
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 5))

        // Setup Podcast Subscription
        if requiresSetup() {
            setupSubscriptions()
        }
    }
}

// MARK: - Helpers

extension GenerateScreenshots {
    var hittablePlayButton: XCUIElement {
        return app.buttons.containing(.button, identifier: "play pause button").allElementsBoundByIndex.first(where: { $0.isHittable && $0.exists })!
    }

    var backButton: XCUIElement {
        return app.navigationBars.buttons.element(boundBy: 0)
    }

    func requiresSetup() -> Bool {
        selectTab(.podcasts)
        return app.buttons["Discover Podcasts"].exists
    }

    func setupSubscriptions() {
        // Open each feed through the app's subscribe link, which shows the podcast page once the feed is loaded
        for feed in Config.podcastFeeds {
            safari.launch()
            XCTAssert(safari.wait(for: .runningForeground, timeout: 5))
            safariLoad(url: "pktc://subscribe/\(feed)")
            safari.buttons["Open"].waitForThenTap()

            XCTAssert(app.wait(for: .runningForeground, timeout: 5))
            app.buttons["Follow"].waitForThenTap(timeout: 60)
            backButton.waitForThenTap()
        }
    }

    func safariLoad(url: String) {
        // Setup Podcast subscription
        safari.descendants(matching: .any)["Address"].waitForThenTap()
        safari.typeText(url)
        safari.buttons["Go"].tap()
    }

    func selectTab(_ tab: Tab) {
        app.tabBars.firstMatch.buttons.element(boundBy: tab.rawValue).waitForThenTap()
    }

    /// Opens the episode whose title contains `key`, scrolling down the episode list until it's on screen
    func openEpisode(_ key: String) {
        let episode = app.cells.containing(NSPredicate(format: "label CONTAINS %@", key)).firstMatch
        if !episode.waitForExistence(timeout: 5) {
            var swipes = 0
            while !episode.exists, swipes < 30 {
                app.swipeUp()
                swipes += 1
            }
        }
        episode.waitForThenTap()
    }

    func navigateToApperance() {
        selectTab(.profile)
        app.buttons["Settings"].waitForThenTap()
        app.staticTexts["appearance"].waitForThenTap()
    }

    func enableSystemThemeMatching() {
        let systemThemeToggle = app.switches["system theme toggle"]
        systemThemeToggle.expectExistence()
        if let value = systemThemeToggle.value as? String, value == "0" {
            systemThemeToggle.tap()
        }
    }

    func scrollToAndTap(_ element: XCUIElement) {
        let initialScrollPercent = app.collectionViews.scrollPercent()
        var traversedDown = initialScrollPercent == 100
        var traversedUp = initialScrollPercent == 0
        while !element.isHittable {
            if !traversedDown {
                app.swipeUp()
                traversedDown = app.collectionViews.scrollPercent() == 100
            } else if !traversedUp {
                app.swipeDown()
                traversedUp = app.collectionViews.scrollPercent() == 0
            } else {
                break
            }
        }

        element.tap()
    }
}
