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
        
        // Primary action: Calculate and show result
        let calculateAction = MathCommandAction(
            id: "\(mathId)-calculate",
            displayName: "Calculate",
            expression: queryExpression,
            commandId: mathId,
            eventPublisher: context.eventPublisher,
            iconName: "equal.circle",
            keyboardShortcut: "↩",
            description: "Calculate the result"
        )
        
        // Secondary action: Calculate and copy to clipboard
        let copyResultAction = MathCopyCommandAction(
            id: "\(mathId)-copy",
            displayName: "Copy Result",
            expression: queryExpression,
            commandId: mathId,
            eventPublisher: context.eventPublisher,
            iconName: "doc.on.clipboard",
            description: "Calculate and copy result to clipboard"
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