import Foundation
import os

enum Log {
    private static let logger = Logger(subsystem: "com.example.spacestrator", category: "core")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        print("[workspace] \(message)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        FileHandle.standardError.write(Data("[workspace][error] \(message)\n".utf8))
    }

    /// Plain stdout — used by the snapshot command so the JSON can be piped/copied,
    /// mirroring the original `print(json.encode(...))` to the Hammerspoon console.
    static func raw(_ message: String) {
        print(message)
    }
}
