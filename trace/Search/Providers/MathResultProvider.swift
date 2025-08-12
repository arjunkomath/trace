//
//  MathResultProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation

class MathResultProvider: ResultProvider {
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        guard MathEvaluator.isMathExpression(context.query) else {
            return []
        }
        
        let mathId = "com.trace.command.math"
        let queryExpression = context.query
        let updateCallback = context.updateCachedResults
        
        // Primary action: Calculate and show result
        let calculateAction = MathCommandAction(
            id: "\(mathId)-calculate",
            displayName: "Calculate",
            expression: queryExpression,
            iconName: "equal.circle",
            keyboardShortcut: "↩",
            description: "Calculate the result",
            onResult: { result in
                Task { @MainActor in
                    updateCallback(mathId) { updatedResult in
                        return SearchResult(
                            title: "\(queryExpression) = \(result)",
                            subtitle: "Math calculation result",
                            icon: updatedResult.icon,
                            type: updatedResult.type,
                            category: updatedResult.category,
                            shortcut: updatedResult.shortcut,
                            lastUsed: updatedResult.lastUsed,
                            commandId: updatedResult.commandId,
                            isLoading: false,
                            accessory: .status("Calculated", .green),
                            commandAction: updatedResult.commandAction
                        )
                    }
                }
            }
        )
        
        // Secondary action: Calculate and copy to clipboard
        let copyResultAction = MathCopyCommandAction(
            id: "\(mathId)-copy",
            displayName: "Copy Result",
            expression: queryExpression,
            iconName: "doc.on.clipboard",
            description: "Calculate and copy result to clipboard",
            onResult: { result in
                Task { @MainActor in
                    updateCallback(mathId) { updatedResult in
                        return SearchResult(
                            title: "\(queryExpression) = \(result)",
                            subtitle: "Copied \(result) to clipboard",
                            icon: updatedResult.icon,
                            type: updatedResult.type,
                            category: updatedResult.category,
                            shortcut: updatedResult.shortcut,
                            lastUsed: updatedResult.lastUsed,
                            commandId: updatedResult.commandId,
                            isLoading: false,
                            accessory: .status("Copied", .blue),
                            commandAction: updatedResult.commandAction
                        )
                    }
                }
            }
        )
        
        // Create multi-action container
        let mathMultiAction = MultiCommandAction(
            id: mathId,
            primaryAction: calculateAction,
            secondaryActions: [copyResultAction]
        )
        
        let mathResult = SearchResult(
            title: "\(context.query) = ?",
            subtitle: "Calculate math expression",
            icon: .system("plus.forwardslash.minus"),
            type: .math,
            category: nil,
            shortcut: nil,
            lastUsed: nil,
            commandId: mathId,
            isLoading: false,
            accessory: nil,
            commandAction: mathMultiAction
        )
        
        // Math results get high priority (score 1.0)
        return [(mathResult, 1.0)]
    }
}