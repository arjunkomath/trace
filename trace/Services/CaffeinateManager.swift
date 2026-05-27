//
//  CaffeinateManager.swift
//  trace
//
//  Created by Codex on 27/5/2026.
//

import Foundation

final class CaffeinateManager {
    static let statusDidChangeNotification = Notification.Name("CaffeinateManagerStatusDidChange")
    static let defaultFlags = "-dims"

    private let logger = AppLogger.caffeinateManager
    private let lock = NSLock()
    private var process: Process?
    private var isStopping = false
    private var shouldShowUnexpectedExitToast = false

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }

        return process?.isRunning == true
    }

    @discardableResult
    func start(showFailureToast: Bool = true) -> Bool {
        let flagsText = SettingsManager.shared.settings.caffeinateFlags
        let arguments: [String]

        do {
            arguments = try Self.arguments(from: flagsText)
        } catch {
            logger.error("Invalid caffeinate flags: \(error.localizedDescription)")
            if showFailureToast {
                ToastManager.shared.showError("Invalid Caffeinate flags")
            }
            return false
        }

        lock.lock()
        if process?.isRunning == true {
            lock.unlock()
            return true
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = arguments
        task.terminationHandler = { [weak self] terminatedProcess in
            self?.handleProcessTermination(terminatedProcess)
        }

        process = task
        isStopping = false
        shouldShowUnexpectedExitToast = showFailureToast
        lock.unlock()

        do {
            try task.run()
            logger.notice("Started caffeinate \(arguments.joined(separator: " "), privacy: .public) with pid \(task.processIdentifier)")
            postStatusChanged()
            return true
        } catch {
            lock.lock()
            if process === task {
                process = nil
                isStopping = false
                shouldShowUnexpectedExitToast = false
            }
            lock.unlock()

            logger.error("Failed to start caffeinate: \(error.localizedDescription)")
            if showFailureToast {
                ToastManager.shared.showError("Failed to start Caffeinate")
            }
            postStatusChanged()
            return false
        }
    }

    func stop() {
        stop(postNotification: true)
    }

    private func stop(postNotification: Bool) {
        lock.lock()
        guard let task = process else {
            lock.unlock()
            return
        }

        process = nil
        isStopping = true
        shouldShowUnexpectedExitToast = false
        lock.unlock()

        if task.isRunning {
            logger.notice("Stopping caffeinate with pid \(task.processIdentifier)")
            task.terminate()
        }

        if postNotification {
            postStatusChanged()
        }
    }

    @discardableResult
    func toggle() -> Bool {
        if isActive {
            stop()
            return false
        }

        return start()
    }

    private func handleProcessTermination(_ terminatedProcess: Process) {
        lock.lock()
        guard process === terminatedProcess else {
            lock.unlock()
            return
        }

        process = nil
        let exitedSuccessfully = terminatedProcess.terminationStatus == 0
        let shouldShowToast = shouldShowUnexpectedExitToast && !isStopping && !exitedSuccessfully
        isStopping = false
        shouldShowUnexpectedExitToast = false
        lock.unlock()

        if exitedSuccessfully {
            logger.notice("Caffeinate exited normally")
        } else {
            logger.warning("Caffeinate exited with status \(terminatedProcess.terminationStatus)")
        }
        postStatusChanged()

        if shouldShowToast {
            ToastManager.shared.showError("Caffeinate stopped unexpectedly")
        }
    }

    private func postStatusChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.statusDidChangeNotification, object: self)
        }
    }

    static func arguments(from flagsText: String) throws -> [String] {
        let tokens = flagsText
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        var arguments: [String] = []
        var index = 0

        while index < tokens.count {
            let token = tokens[index]

            guard token.hasPrefix("-"), token.count > 1 else {
                throw CaffeinateFlagsError.unsupportedArgument(token)
            }

            if token == "-t" {
                guard index + 1 < tokens.count else {
                    throw CaffeinateFlagsError.missingTimeout
                }

                let timeout = tokens[index + 1]
                guard isValidTimeout(timeout) else {
                    throw CaffeinateFlagsError.invalidTimeout(timeout)
                }

                arguments.append(token)
                arguments.append(timeout)
                index += 2
                continue
            }

            let flagCharacters = token.dropFirst()
            guard !flagCharacters.contains("t") else {
                throw CaffeinateFlagsError.unsupportedFlag(token)
            }

            let allowedFlags = Set("dimsu")
            guard flagCharacters.allSatisfy({ allowedFlags.contains($0) }) else {
                throw CaffeinateFlagsError.unsupportedFlag(token)
            }

            arguments.append(token)
            index += 1
        }

        return arguments
    }

    static func flagsValidationMessage(_ flagsText: String) -> String? {
        do {
            _ = try arguments(from: flagsText)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private static func isValidTimeout(_ timeout: String) -> Bool {
        guard let seconds = Int(timeout), seconds > 0 else {
            return false
        }

        return String(seconds) == timeout
    }

    deinit {
        stop(postNotification: false)
    }
}

private enum CaffeinateFlagsError: LocalizedError {
    case unsupportedArgument(String)
    case unsupportedFlag(String)
    case missingTimeout
    case invalidTimeout(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedArgument(let argument):
            return "Only caffeinate flags are allowed; '\(argument)' is not supported."
        case .unsupportedFlag(let flag):
            return "Unsupported flag '\(flag)'. Use -d, -i, -m, -s, -u, or -t <seconds>."
        case .missingTimeout:
            return "-t requires a timeout in seconds."
        case .invalidTimeout(let timeout):
            return "'\(timeout)' is not a valid timeout in seconds."
        }
    }
}
