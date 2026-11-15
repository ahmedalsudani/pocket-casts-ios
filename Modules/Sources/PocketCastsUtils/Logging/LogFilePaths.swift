import Foundation

public enum LogFilePaths {
    static var mainLogFilePath: String { logDirectory + "/main.log" }

    static var backupLogFilePath: String { logDirectory + "/old.log" }

    static var logDirectory: String {
        let directory = (NSHomeDirectory() as NSString).appendingPathComponent("Documents/debug_log")
        return directory
    }
}
