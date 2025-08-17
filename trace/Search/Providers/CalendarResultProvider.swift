//
//  CalendarResultProvider.swift
//  trace
//
//  Created by Claude on 17/8/2025.
//

import Foundation

class CalendarResultProvider: ResultProvider {
    private let calendarManager = CalendarManager.shared
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        // Only return results if calendar search is enabled
        guard context.services.settingsManager.settings.calendarSearchEnabled else {
            return []
        }
        
        guard calendarManager.hasPermission else {
            return []
        }
        
        // Ensure events are loaded
        await calendarManager.loadEvents()
        
        let matchingEvents = calendarManager.searchEvents(query: query)
        
        var results: [(SearchResult, Double)] = []
        
        for event in matchingEvents {
            let searchTerms = [
                event.title,
                event.location ?? "",
                event.notes ?? "",
                event.attendees.joined(separator: " ")
            ].filter { !$0.isEmpty }
            
            let matchScore = matchesSearchTerms(query: query, terms: searchTerms)
            
            // Use prefixed event ID for usage tracking
            let prefixedEventId = "com.trace.calendar.\(event.id)"
            let usageScore = context.usageScores[prefixedEventId] ?? 0
            
            if let finalScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                let commandAction = CalendarCommandAction(
                    id: "calendar_\(event.id)",
                    displayName: event.title,
                    eventId: event.id,
                    iconName: "calendar"
                )
                
                let searchResult = SearchResult(
                    title: event.title,
                    subtitle: event.subtitle,
                    icon: .system("calendar"),
                    type: .calendar,
                    category: nil,
                    shortcut: nil,
                    lastUsed: nil,
                    commandId: "com.trace.calendar.\(event.id)",
                    accessory: getEventAccessory(for: event),
                    commandAction: commandAction
                )
                
                results.append((searchResult, finalScore))
            }
        }
        
        // Sort by relevance and limit results
        return results.sorted { $0.1 > $1.1 }.prefix(AppConstants.Search.calendarResultLimit).map { $0 }
    }
    
    private func getEventAccessory(for event: CalendarEvent) -> SearchResultAccessory? {
        let now = Date()
        
        if event.startDate <= now && event.endDate >= now {
            // Event is happening now
            return .status("Now", .green)
        } else if event.startDate > now {
            // Future event - show time until
            let timeInterval = event.startDate.timeIntervalSince(now)
            
            if timeInterval < 3600 { // Less than 1 hour
                let minutes = Int(timeInterval / 60)
                return .status("\(minutes)m", .orange)
            } else if timeInterval < 86400 { // Less than 1 day
                let hours = Int(timeInterval / 3600)
                return .status("\(hours)h", .blue)
            } else {
                // More than 1 day - show calendar name
                return .badge(event.calendar.title)
            }
        } else {
            // Past event
            return .badge(event.calendar.title)
        }
    }
}