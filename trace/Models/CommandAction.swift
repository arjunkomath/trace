//
//  CommandAction.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation
import AppKit
import os.log

// MARK: - Command Action Protocols

protocol CommandAction {
    var id: String { get }
    var showsLoadingState: Bool { get }
    
    func execute() async -> ActionResult
}

protocol DisplayableCommandAction: CommandAction {
    var displayName: String { get }
    var iconName: String? { get }
    var keyboardShortcut: String? { get }
    var description: String? { get }
}

// MARK: - Multi-Action Types

struct MultiCommandAction: CommandAction {
    let id: String
    let primaryAction: DisplayableCommandAction
    let secondaryActions: [DisplayableCommandAction]
    
    var showsLoadingState: Bool {
        return primaryAction.showsLoadingState
    }
    
    var hasMultipleActions: Bool {
        return !secondaryActions.isEmpty
    }
    
    var allActions: [DisplayableCommandAction] {
        return [primaryAction] + secondaryActions
    }
    
    func execute() async -> ActionResult {
        return await primaryAction.execute()
    }
    
    func getAction(by actionId: String) -> DisplayableCommandAction? {
        return allActions.first { $0.id == actionId }
    }
}

// MARK: - Action Result

enum ActionResult {
    case success(message: String?, data: ActionData?)
    case failure(error: String)
    
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

enum ActionData {
    case text(String)
    case url(URL)
    case application(Application)
}

// MARK: - Action Executor

@MainActor
class ActionExecutor: ObservableObject {
    @Published private(set) var loadingActions: Set<String> = []
    private let logger = AppLogger.actionExecutor
    
    func execute(_ action: CommandAction, onComplete: @escaping (Bool) -> Void) {
        guard !isLoading(action.id) else {
            logger.warning("Action \(action.id) is already executing")
            return
        }
        
        Task {
            // Set loading state asynchronously to avoid publishing during view update
            if action.showsLoadingState {
                await MainActor.run {
                    setLoading(action.id, true)
                }
            }
            
            let result = await action.execute()
            
            await MainActor.run {
                if action.showsLoadingState {
                    setLoading(action.id, false)
                }
                
                handleResult(result, for: action)
                
                // Call completion with success status, let caller decide whether to close
                onComplete(result.isSuccess)
            }
        }
    }
    
    func executeAction(by actionId: String, from commandAction: CommandAction, onComplete: @escaping (Bool) -> Void) {
        // Handle multi-action execution
        if let multiAction = commandAction as? MultiCommandAction,
           let specificAction = multiAction.getAction(by: actionId) {
            execute(specificAction, onComplete: onComplete)
        } else {
            // Fallback to primary action
            execute(commandAction, onComplete: onComplete)
        }
    }
    
    func isLoading(_ actionId: String) -> Bool {
        return loadingActions.contains(actionId)
    }
    
    private func setLoading(_ actionId: String, _ loading: Bool) {
        if loading {
            loadingActions.insert(actionId)
        } else {
            loadingActions.remove(actionId)
        }
    }
    
    private func handleResult(_ result: ActionResult, for action: CommandAction) {
        switch result {
        case .success(let message, let data):
            logger.info("Action \(action.id) completed successfully")
            
            // Handle data-specific actions
            if let data = data {
                handleActionData(data)
            }
            
            // Show success notification if message provided
            if let message = message {
                showNotification(title: "Success", message: message, isError: false)
            }
            
        case .failure(let error):
            logger.error("Action \(action.id) failed: \(error)")
            showNotification(title: "Error", message: error, isError: true)
        }
    }
    
    private func handleActionData(_ data: ActionData) {
        switch data {
        case .text(let text):
            copyToClipboard(text)
            
        case .url(let url):
            NSWorkspace.shared.open(url)
            
        case .application(let app):
            do {
                try NSWorkspace.shared.launchApplication(at: app.url, options: [], configuration: [:])
            } catch {
                logger.error("Failed to launch application: \(error)")
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        logger.info("Copied to clipboard: \(text)")
    }
    
    private func showNotification(title: String, message: String, isError: Bool) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = isError ? NSUserNotificationDefaultSoundName : nil
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// MARK: - Concrete Action Types

struct NetworkCommandAction: DisplayableCommandAction {
    let id: String
    let displayName: String
    let iconName: String?
    let keyboardShortcut: String?
    let description: String?
    let networkOperation: () async -> String?
    let showsLoadingState = true
    let skipClipboard: Bool
    private let eventPublisher: ResultEventPublisher
    private let commandId: String
    
    init(
        id: String,
        displayName: String,
        commandId: String,
        eventPublisher: ResultEventPublisher,
        iconName: String? = nil,
        keyboardShortcut: String? = nil,
        description: String? = nil,
        networkOperation: @escaping () async -> String?,
        skipClipboard: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.commandId = commandId
        self.eventPublisher = eventPublisher
        self.iconName = iconName
        self.keyboardShortcut = keyboardShortcut
        self.description = description
        self.networkOperation = networkOperation
        self.skipClipboard = skipClipboard
    }
    
    
    func execute() async -> ActionResult {
        eventPublisher.publishUpdate(.loading(commandId: commandId))
        
        guard let result = await networkOperation() else {
            eventPublisher.publishUpdate(.failed(commandId: commandId, error: "Failed to fetch \(displayName.lowercased())"))
            return .failure(error: "Failed to fetch \(displayName.lowercased())")
        }
        
        if skipClipboard {
            eventPublisher.publishUpdate(.completed(
                commandId: commandId,
                newTitle: "\(displayName): \(result)",
                newSubtitle: "Fetched successfully",
                accessory: .status("Fetched", .blue)
            ))
            return .success(
                message: "\(displayName): \(result)",
                data: nil
            )
        } else {
            // Copy to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(result, forType: .string)
            
            eventPublisher.publishUpdate(.completed(
                commandId: commandId,
                newTitle: "\(displayName): \(result)",
                newSubtitle: "Copied \(result) to clipboard",
                accessory: .status("Copied", .green)
            ))
            return .success(
                message: "\(displayName) \(result) copied to clipboard",
                data: .text(result)
            )
        }
    }
}

struct InstantCommandAction: DisplayableCommandAction {
    let id: String
    let displayName: String
    let iconName: String?
    let keyboardShortcut: String?
    let description: String?
    let operation: () -> Void
    let showsLoadingState = false
    
    init(
        id: String,
        displayName: String,
        iconName: String? = nil,
        keyboardShortcut: String? = nil,
        description: String? = nil,
        operation: @escaping () -> Void
    ) {
        self.id = id
        self.displayName = displayName
        self.iconName = iconName
        self.keyboardShortcut = keyboardShortcut
        self.description = description
        self.operation = operation
    }
    
    func execute() async -> ActionResult {
        operation()
        return .success(message: nil, data: nil)
    }
}

struct URLCommandAction: DisplayableCommandAction {
    let id: String
    let displayName: String
    let iconName: String?
    let keyboardShortcut: String?
    let description: String?
    let url: URL
    let showsLoadingState = false
    
    init(
        id: String,
        displayName: String,
        iconName: String? = nil,
        keyboardShortcut: String? = nil,
        description: String? = nil,
        url: URL
    ) {
        self.id = id
        self.displayName = displayName
        self.iconName = iconName
        self.keyboardShortcut = keyboardShortcut
        self.description = description
        self.url = url
    }
    
    func execute() async -> ActionResult {
        return .success(message: nil, data: .url(url))
    }
}

struct MathCommandAction: DisplayableCommandAction {
    let id: String
    let displayName: String
    let iconName: String?
    let keyboardShortcut: String?
    let description: String?
    let expression: String
    let showsLoadingState = true
    private let eventPublisher: ResultEventPublisher
    private let commandId: String
    
    init(
        id: String,
        displayName: String,
        expression: String,
        commandId: String,
        eventPublisher: ResultEventPublisher,
        iconName: String? = nil,
        keyboardShortcut: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.expression = expression
        self.commandId = commandId
        self.eventPublisher = eventPublisher
        self.iconName = iconName
        self.keyboardShortcut = keyboardShortcut
        self.description = description
    }
    
    func execute() async -> ActionResult {
        eventPublisher.publishUpdate(.loading(commandId: commandId))
        
        guard let result = await MathEvaluator.evaluate(expression) else {
            eventPublisher.publishUpdate(.failed(commandId: commandId, error: "Unable to calculate \(expression)"))
            return .failure(error: "Unable to calculate \(expression)")
        }
        
        eventPublisher.publishUpdate(.completed(
            commandId: commandId,
            newTitle: "\(expression) = \(result)",
            newSubtitle: "Math calculation result",
            accessory: .status("Calculated", .green)
        ))
        
        return .success(
            message: nil,
            data: nil
        )
    }
}

struct MathCopyCommandAction: DisplayableCommandAction {
    let id: String
    let displayName: String
    let iconName: String?
    let keyboardShortcut: String?
    let description: String?
    let expression: String
    let showsLoadingState = true
    private let eventPublisher: ResultEventPublisher
    private let commandId: String
    
    init(
        id: String,
        displayName: String,
        expression: String,
        commandId: String,
        eventPublisher: ResultEventPublisher,
        iconName: String? = nil,
        keyboardShortcut: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.expression = expression
        self.commandId = commandId
        self.eventPublisher = eventPublisher
        self.iconName = iconName
        self.keyboardShortcut = keyboardShortcut
        self.description = description
    }
    
    func execute() async -> ActionResult {
        eventPublisher.publishUpdate(.loading(commandId: commandId))
        
        guard let result = await MathEvaluator.evaluate(expression) else {
            eventPublisher.publishUpdate(.failed(commandId: commandId, error: "Unable to calculate \(expression)"))
            return .failure(error: "Unable to calculate \(expression)")
        }
        
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result, forType: .string)
        
        eventPublisher.publishUpdate(.completed(
            commandId: commandId,
            newTitle: "\(expression) = \(result)",
            newSubtitle: "Copied \(result) to clipboard",
            accessory: .status("Copied", .blue)
        ))
        
        return .success(
            message: "Result \(result) copied to clipboard",
            data: .text(result)
        )
    }
}