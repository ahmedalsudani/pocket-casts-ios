import Foundation

public enum ServerConstants {
    public enum HttpConstants {
        public static let notModified = 304
        public static let notFound = 404
    }

    public enum HttpHeaders {
        public static let lastModified = "Last-Modified"
        public static let ifModifiedSince = "If-Modified-Since"
        public static let ifNoneMatch = "If-None-Match"
        public static let contentType = "Content-Type"
        public static let accept = "Accept"
        public static let userAgent = "User-Agent"
        public static let etag = "ETag"
    }

    public enum Values {
        public static let appUserAgent = "Pocket Casts"

        static let oldEpisodeCutoff = 2.weeks
    }

    public enum UserDefaults {
        static let lastRefreshStartTime = "LastRefreshStartTime"
        static let lastRefreshEndTime = "SJLastRefreshDate"
        public static let audioOnlyKey = "SJAudioOnly"
        static let statsStartDate = "StatsStartDate"
        static let statsDynamicSpeedSeconds = "StatsDynamicSpeed"
        static let statsVariableSpeed = "StatsVariableSpeed"
        static let statsListenedTo = "StatsListenedTo"
        static let statsSkipped = "StatsSkipped"
        static let statsAutoSkip = "StatsIntroSKip"
        static let statsDynamicSpeedSecondsServer = "StatsDynamicSpeedServer"
        static let statsVariableSpeedServer = "StatsVariableSpeedServer"
        static let statsListenedToServer = "StatsListenedToServer"
        static let statsSkippedServer = "StatsSkippedServer"
        static let statsAutoSkipServer = "StatsIntroSkipServer"
        static let statsStartedDateServer = "StatsStartedDateServer"
    }
}
