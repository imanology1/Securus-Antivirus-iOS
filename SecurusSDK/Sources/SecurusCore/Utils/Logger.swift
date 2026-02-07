// ============================================================================
// Logger.swift
// SecurusCore
//
// Internal logging facility for the Securus SDK. All log messages are
// prefixed with [Securus] and filtered by the configured log level.
// ============================================================================

import Foundation
import os.log

// MARK: - LogLevel

/// Verbosity levels for the Securus internal logger.
public enum LogLevel: Int, Comparable, Sendable {
    /// Verbose diagnostic output for development.
    case debug = 0
    /// General informational messages about SDK lifecycle events.
    case info = 1
    /// Potentially harmful situations that do not prevent operation.
    case warning = 2
    /// Errors that may cause degraded functionality.
    case error = 3
    /// Suppress all logging output.
    case none = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - SecurusLogger

/// Thread-safe internal logger for the Securus SDK.
///
/// All output is prefixed with `[Securus]` and the originating subsystem.
/// The logger respects the globally configured `logLevel` and suppresses
/// messages below that threshold.
///
/// Usage:
/// ```swift
/// SecurusLogger.shared.debug("Baseline updated", subsystem: "Network")
/// SecurusLogger.shared.error("Keychain write failed", subsystem: "Storage")
/// ```
public final class SecurusLogger: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared logger instance.
    public static let shared = SecurusLogger()

    // MARK: - Properties

    /// Current log level threshold. Messages below this level are discarded.
    public var logLevel: LogLevel {
        get { queue.sync { _logLevel } }
        set { queue.sync { _logLevel = newValue } }
    }

    private var _logLevel: LogLevel = .warning
    private let queue = DispatchQueue(label: "com.securus.logger", attributes: .concurrent)
    private let osLog = OSLog(subsystem: "com.securus.sdk", category: "Securus")

    // MARK: - Private Tag

    private static let tag = "[Securus]"

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Log a debug-level message.
    public func debug(_ message: @autoclosure () -> String,
                      subsystem: String = "Core",
                      file: String = #fileID,
                      line: Int = #line) {
        log(level: .debug, message: message(), subsystem: subsystem, file: file, line: line)
    }

    /// Log an info-level message.
    public func info(_ message: @autoclosure () -> String,
                     subsystem: String = "Core",
                     file: String = #fileID,
                     line: Int = #line) {
        log(level: .info, message: message(), subsystem: subsystem, file: file, line: line)
    }

    /// Log a warning-level message.
    public func warning(_ message: @autoclosure () -> String,
                        subsystem: String = "Core",
                        file: String = #fileID,
                        line: Int = #line) {
        log(level: .warning, message: message(), subsystem: subsystem, file: file, line: line)
    }

    /// Log an error-level message.
    public func error(_ message: @autoclosure () -> String,
                      subsystem: String = "Core",
                      file: String = #fileID,
                      line: Int = #line) {
        log(level: .error, message: message(), subsystem: subsystem, file: file, line: line)
    }

    // MARK: - Internal

    private func log(level: LogLevel,
                     message: String,
                     subsystem: String,
                     file: String,
                     line: Int) {
        guard level >= logLevel else { return }

        let emoji: String
        let osLogType: OSLogType
        switch level {
        case .debug:
            emoji = "D"
            osLogType = .debug
        case .info:
            emoji = "I"
            osLogType = .info
        case .warning:
            emoji = "W"
            osLogType = .default
        case .error:
            emoji = "E"
            osLogType = .error
        case .none:
            return
        }

        let formattedMessage = "\(Self.tag)[\(subsystem)][\(emoji)] \(message)"

        // Emit to Apple unified logging
        os_log("%{public}@", log: osLog, type: osLogType, formattedMessage)

        #if DEBUG
        // Also emit to stdout during development for convenience
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("\(timestamp) \(formattedMessage) (\(file):\(line))")
        #endif
    }
}
