import Foundation
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "CrashReporting")

// MARK: - Crash Reporting Protocol

protocol CrashReportingService {
    func initialize()
    func logError(_ error: Error, context: [String: Any]?)
    func logMessage(_ message: String, level: LogLevel)
    func setUser(id: String?, email: String?, username: String?)
    func setBreadcrumb(message: String, category: String, level: LogLevel)
    func captureException(_ exception: NSException)
    func captureMessage(_ message: String, level: LogLevel)
    func addTag(_ key: String, value: String)
    func setContext(_ key: String, value: [String: Any])
    func startTransaction(name: String, operation: String) -> Transaction?
}

// MARK: - Transaction Protocol

protocol Transaction {
    func setData(_ key: String, value: Any)
    func setMeasurement(_ name: String, value: Double, unit: MeasurementUnit)
    func finish(status: TransactionStatus)
}

enum TransactionStatus: CustomStringConvertible {
    case ok
    case cancelled
    case internalError
    case invalidArgument
    case deadlineExceeded
    case notFound
    case alreadyExists
    case permissionDenied
    case resourceExhausted
    case aborted
    case unknown

    var description: String {
        switch self {
        case .ok: return "ok"
        case .cancelled: return "cancelled"
        case .internalError: return "internal_error"
        case .invalidArgument: return "invalid_argument"
        case .deadlineExceeded: return "deadline_exceeded"
        case .notFound: return "not_found"
        case .alreadyExists: return "already_exists"
        case .permissionDenied: return "permission_denied"
        case .resourceExhausted: return "resource_exhausted"
        case .aborted: return "aborted"
        case .unknown: return "unknown"
        }
    }
}

enum MeasurementUnit: CustomStringConvertible {
    case nanosecond
    case microsecond
    case millisecond
    case second
    case minute
    case hour
    case day
    case byte
    case kilobyte
    case megabyte
    case gigabyte
    case percent
    case custom(String)

    var description: String {
        switch self {
        case .nanosecond: return "ns"
        case .microsecond: return "μs"
        case .millisecond: return "ms"
        case .second: return "s"
        case .minute: return "min"
        case .hour: return "h"
        case .day: return "d"
        case .byte: return "B"
        case .kilobyte: return "KB"
        case .megabyte: return "MB"
        case .gigabyte: return "GB"
        case .percent: return "%"
        case .custom(let unit): return unit
        }
    }
}

// MARK: - Sentry Implementation

final class SentryCrashReporting: CrashReportingService {
    static let shared = SentryCrashReporting()

    private init() {}

    func initialize() {
        #if !DEBUG
        // In production, you would initialize Sentry here
        // SentrySDK.start { options in
        //     options.dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"] ?? ""
        //     options.environment = "production"
        //     options.enableAutoSessionTracking = true
        //     options.attachScreenshot = true
        //     options.enableAutoPerformanceTracking = true
        //     options.tracesSampleRate = 0.2
        // }
        logger.info("Sentry crash reporting initialized")
        #else
        logger.debug("Sentry disabled in debug mode")
        #endif
    }

    func logError(_ error: Error, context: [String: Any]?) {
        logger.error("Error logged: \(error.localizedDescription)")

        #if !DEBUG
        // SentrySDK.capture(error: error) { scope in
        //     if let context = context {
        //         scope.setContext(value: context, key: "error_context")
        //     }
        // }
        #endif

        // Also log to our custom logger
        if let appError = error as? AppError {
            logAppError(appError, context: context)
        }
    }

    func logMessage(_ message: String, level: LogLevel) {
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        case .critical:
            logger.critical("\(message)")
        }

        #if !DEBUG
        // let sentryLevel = mapToSentryLevel(level)
        // SentrySDK.capture(message: message, with: sentryLevel)
        #endif
    }

    func setUser(id: String?, email: String?, username: String?) {
        #if !DEBUG
        // let user = User()
        // user.userId = id
        // user.email = email
        // user.username = username
        // SentrySDK.setUser(user)
        #endif

        logger.debug("User context updated")
    }

    func setBreadcrumb(message: String, category: String, level: LogLevel) {
        #if !DEBUG
        // let breadcrumb = Breadcrumb()
        // breadcrumb.message = message
        // breadcrumb.category = category
        // breadcrumb.level = mapToSentryLevel(level)
        // SentrySDK.addBreadcrumb(breadcrumb)
        #endif

        logger.debug("Breadcrumb: [\(category)] \(message)")
    }

    func captureException(_ exception: NSException) {
        logger.error("Exception captured: \(exception.name.rawValue) - \(exception.reason ?? "Unknown")")

        #if !DEBUG
        // SentrySDK.capture(exception: exception)
        #endif
    }

    func captureMessage(_ message: String, level: LogLevel) {
        logMessage(message, level: level)
    }

    func addTag(_ key: String, value: String) {
        #if !DEBUG
        // SentrySDK.configureScope { scope in
        //     scope.setTag(value: value, key: key)
        // }
        #endif
    }

    func setContext(_ key: String, value: [String: Any]) {
        #if !DEBUG
        // SentrySDK.configureScope { scope in
        //     scope.setContext(value: value, key: key)
        // }
        #endif
    }

    func startTransaction(name: String, operation: String) -> Transaction? {
        #if !DEBUG
        // Sentry disabled for now - return mock transaction
        // let transaction = SentrySDK.startTransaction(name: name, operation: operation)
        // return SentryTransaction(transaction: transaction)
        return MockTransaction(name: name, operation: operation)
        #else
        return MockTransaction(name: name, operation: operation)
        #endif
    }

    // MARK: - Private Helpers

    private func logAppError(_ error: AppError, context: [String: Any]?) {
        var errorContext = context ?? [:]
        errorContext["error_type"] = String(describing: error)
        errorContext["error_id"] = error.id

        if let description = error.errorDescription {
            errorContext["description"] = description
        }

        if let recovery = error.recoverySuggestion {
            errorContext["recovery"] = recovery
        }

        errorContext["is_retryable"] = error.isRetryable

        #if !DEBUG
        // SentrySDK.configureScope { scope in
        //     scope.setContext(value: errorContext, key: "app_error")
        // }
        #endif
    }

    private func mapToSentryLevel(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "debug"
        case .info: return "info"
        case .warning: return "warning"
        case .error: return "error"
        case .critical: return "fatal"
        }
    }
}

// MARK: - Mock Transaction for Development

private class MockTransaction: Transaction {
    let name: String
    let operation: String
    var data: [String: Any] = [:]
    var measurements: [String: Double] = [:]

    init(name: String, operation: String) {
        self.name = name
        self.operation = operation
        logger.debug("Started transaction: \(name) - \(operation)")
    }

    func setData(_ key: String, value: Any) {
        data[key] = value
    }

    func setMeasurement(_ name: String, value: Double, unit: MeasurementUnit) {
        measurements[name] = value
        logger.debug("Measurement: \(name) = \(value) \(unit)")
    }

    func finish(status: TransactionStatus) {
        logger.debug("Finished transaction: \(self.name) with status: \(status)")
    }
}

// MARK: - Crash Reporter Manager

@MainActor
final class CrashReporter {
    static let shared = CrashReporter()
    private let service: CrashReportingService = SentryCrashReporting.shared

    private init() {}

    func initialize() {
        service.initialize()
        setupExceptionHandler()
        logger.info("Crash reporter initialized")
    }

    func logError(_ error: Error, context: [String: Any]? = nil) {
        service.logError(error, context: context)
    }

    func logMessage(_ message: String, level: LogLevel = .info) {
        service.logMessage(message, level: level)
    }

    func setUserContext(id: String?, email: String? = nil, username: String? = nil) {
        service.setUser(id: id, email: email, username: username)
    }

    func addBreadcrumb(_ message: String, category: String = "app", level: LogLevel = .info) {
        service.setBreadcrumb(message: message, category: category, level: level)
    }

    func startTransaction(name: String, operation: String) -> Transaction? {
        return service.startTransaction(name: name, operation: operation)
    }

    func trackAppLaunch() {
        let transaction = startTransaction(name: "app.launch", operation: "launch")
        transaction?.setMeasurement("launch_time", value: ProcessInfo.processInfo.systemUptime, unit: .second)
        transaction?.finish(status: .ok)
    }

    // MARK: - Private Helpers

    private func setupExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            logger.critical("Uncaught exception: \(exception)")
            SentryCrashReporting.shared.captureException(exception)
        }
    }
}

// MARK: - Log Level

enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}