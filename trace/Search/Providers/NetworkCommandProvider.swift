//
//  NetworkCommandProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation

class NetworkCommandProvider: ResultProvider {
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        var results: [(SearchResult, Double)] = []
        
        // Public IP Address command
        if let publicIPResult = createPublicIPCommand(query: query, context: context) {
            results.append(publicIPResult)
        }
        
        // Private IP Address command
        if let privateIPResult = createPrivateIPCommand(query: query, context: context) {
            results.append(privateIPResult)
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func createPublicIPCommand(query: String, context: SearchContext) -> (SearchResult, Double)? {
        let publicIPMatchScore = matchesSearchTerms(query: query, terms: [
            "public ip", "external ip", "public ip address", "external ip address", "my ip",
            "ip address", "public", "external", "internet ip", "wan ip", "outside ip"
        ])
        
        let publicIPId = "com.trace.command.publicip"
        let publicIPUsageScore = context.usageScores[publicIPId] ?? 0.0
        
        guard let publicIPScore = calculateUnifiedScore(matchScore: publicIPMatchScore, usageScore: publicIPUsageScore) else {
            return nil
        }
        
        // Primary action: Fetch and display (no clipboard copy)
        let fetchPublicIPAction = NetworkCommandAction(
            id: "\(publicIPId)-fetch",
            displayName: "Fetch IP",
            commandId: publicIPId,
            eventPublisher: context.eventPublisher,
            iconName: "eye",
            keyboardShortcut: "↩",
            description: "Fetch and display your public IP address",
            networkOperation: {
                return await context.services.networkUtilities.getPublicIPAddress()
            },
            skipClipboard: true
        )
        
        // Secondary action: Fetch and copy to clipboard
        let copyPublicIPAction = NetworkCommandAction(
            id: "\(publicIPId)-copy",
            displayName: "Copy to Clipboard",
            commandId: publicIPId,
            eventPublisher: context.eventPublisher,
            iconName: "doc.on.clipboard",
            keyboardShortcut: nil,
            description: "Fetch your public IP address and copy to clipboard",
            networkOperation: {
                return await context.services.networkUtilities.getPublicIPAddress()
            },
            skipClipboard: false
        )
        
        // Create multi-action container
        let publicIPMultiAction = MultiCommandAction(
            id: publicIPId,
            primaryAction: fetchPublicIPAction,
            secondaryActions: [copyPublicIPAction]
        )
        
        let publicIPResult = SearchResult(
            title: "Public IP Address",
            subtitle: "Get your external IP address",
            icon: .system("globe"),
            type: .command,
            category: .network,
            shortcut: nil,
            lastUsed: nil,
            commandId: publicIPId,
            isLoading: false,
            accessory: nil,
            commandAction: publicIPMultiAction
        )
        
        return (publicIPResult, publicIPScore)
    }
    
    private func createPrivateIPCommand(query: String, context: SearchContext) -> (SearchResult, Double)? {
        let privateIPMatchScore = matchesSearchTerms(query: query, terms: [
            "private ip", "local ip", "private ip address", "local ip address", "internal ip",
            "lan ip", "network ip", "private", "local", "internal", "wifi ip", "ethernet ip"
        ])
        
        let privateIPId = "com.trace.command.privateip"
        let privateIPUsageScore = context.usageScores[privateIPId] ?? 0.0
        
        guard let privateIPScore = calculateUnifiedScore(matchScore: privateIPMatchScore, usageScore: privateIPUsageScore) else {
            return nil
        }
        
        // Primary action: Fetch and display (no clipboard copy)
        let fetchPrivateIPAction = NetworkCommandAction(
            id: "\(privateIPId)-fetch",
            displayName: "Fetch IP",
            commandId: privateIPId,
            eventPublisher: context.eventPublisher,
            iconName: "eye",
            keyboardShortcut: "↩",
            description: "Fetch and display your private IP address",
            networkOperation: {
                return context.services.networkUtilities.getPrivateIPAddress()
            },
            skipClipboard: true
        )
        
        // Secondary action: Fetch and copy to clipboard
        let copyPrivateIPAction = NetworkCommandAction(
            id: "\(privateIPId)-copy",
            displayName: "Copy to Clipboard",
            commandId: privateIPId,
            eventPublisher: context.eventPublisher,
            iconName: "doc.on.clipboard",
            keyboardShortcut: nil,
            description: "Fetch your private IP address and copy to clipboard",
            networkOperation: {
                return context.services.networkUtilities.getPrivateIPAddress()
            },
            skipClipboard: false
        )
        
        // Create multi-action container
        let privateIPMultiAction = MultiCommandAction(
            id: privateIPId,
            primaryAction: fetchPrivateIPAction,
            secondaryActions: [copyPrivateIPAction]
        )
        
        let privateIPResult = SearchResult(
            title: "Private IP Address",
            subtitle: "Get your local network IP address",
            icon: .system("wifi"),
            type: .command,
            category: .network,
            shortcut: nil,
            lastUsed: nil,
            commandId: privateIPId,
            isLoading: false,
            accessory: nil,
            commandAction: privateIPMultiAction
        )
        
        return (privateIPResult, privateIPScore)
    }
}