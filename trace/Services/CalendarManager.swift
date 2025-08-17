//
//  CalendarManager.swift
//  trace
//

import Foundation
import EventKit
import AppKit
import os.log

struct CalendarEvent {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let calendar: EKCalendar
    let attendees: [String]
    let isAllDay: Bool
    
    var searchableText: String {
        var text = title
        if let location = location { text += " \(location)" }
        if let notes = notes { text += " \(notes)" }
        text += " " + attendees.joined(separator: " ")
        return text
    }
    
    var formattedDateRange: String {
        let formatter = DateFormatter()
        
        if isAllDay {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            
            if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
                return formatter.string(from: startDate)
            } else {
                return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
            }
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
                formatter.dateStyle = .none
                let timeRange = "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                let date = formatter.string(from: startDate)
                return "\(date) at \(timeRange)"
            } else {
                return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
            }
        }
    }
    
    var subtitle: String {
        var parts: [String] = []
        parts.append(formattedDateRange)
        if let location = location, !location.isEmpty {
            parts.append(location)
        }
        return parts.joined(separator: " • ")
    }
}

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    private let logger = AppLogger.calendarManager
    
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var events: [CalendarEvent] = []
    
    private var lastFetchDate: Date?
    private let cacheExpiryInterval: TimeInterval = 300 // 5 minutes
    
    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        
        // Listen for calendar changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
        
        // Load events if we already have permission
        if hasPermission {
            Task {
                await loadEvents(force: true)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Authorization
    
    func requestAccess() async -> Bool {
        logger.info("Requesting calendar access...")
        logger.info("Current authorization status: \(self.authorizationStatus.rawValue)")
        
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            logger.info("EventKit requestFullAccessToEvents returned: \(granted)")
            
            let newStatus = EKEventStore.authorizationStatus(for: .event)
            logger.info("New authorization status after request: \(newStatus.rawValue)")
            
            await MainActor.run {
                self.authorizationStatus = newStatus
            }
            
            if granted {
                logger.info("Calendar access granted")
                await loadEvents(force: true)
            } else {
                logger.warning("Calendar access denied")
            }
            
            return granted
        } catch {
            logger.error("Failed to request calendar access: \(error.localizedDescription)")
            await MainActor.run {
                self.authorizationStatus = .denied
            }
            return false
        }
    }
    
    var hasPermission: Bool {
        return authorizationStatus == .fullAccess
    }
    
    // MARK: - Event Loading
    
    func loadEvents(force: Bool = false) async {
        guard hasPermission else {
            logger.warning("Cannot load events: no calendar permission")
            return
        }
        
        // Check cache expiry
        if !force,
           let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < cacheExpiryInterval {
            return
        }
        
        let now = Date()
        let pastDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let futureDate = Calendar.current.date(byAdding: .day, value: 90, to: now) ?? now
        
        let predicate = eventStore.predicateForEvents(
            withStart: pastDate,
            end: futureDate,
            calendars: nil
        )
        
        let ekEvents = eventStore.events(matching: predicate)
        
        let calendarEvents = ekEvents.compactMap { ekEvent -> CalendarEvent? in
            guard let eventId = ekEvent.eventIdentifier else { return nil }
            
            let attendeeNames = ekEvent.attendees?.compactMap { attendee in
                attendee.name ?? attendee.url.absoluteString
            } ?? []
            
            return CalendarEvent(
                id: eventId,
                title: ekEvent.title ?? "Untitled Event",
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                location: ekEvent.location,
                notes: ekEvent.notes,
                calendar: ekEvent.calendar,
                attendees: attendeeNames,
                isAllDay: ekEvent.isAllDay
            )
        }
        
        await MainActor.run {
            self.events = calendarEvents.sorted { $0.startDate < $1.startDate }
            self.lastFetchDate = now
        }
        
        logger.info("Loaded \(calendarEvents.count) calendar events")
    }
    
    // MARK: - Search
    
    func searchEvents(query: String) -> [CalendarEvent] {
        guard !query.isEmpty else { 
            logger.debug("Calendar search: empty query")
            return [] 
        }
        
        let lowercaseQuery = query.lowercased()
        
        let matchingEvents = self.events.filter { event in
            event.searchableText.lowercased().contains(lowercaseQuery)
        }
        return matchingEvents
    }
    
    // MARK: - Event Actions
    
    func openEvent(_ event: CalendarEvent) {
        // Method 1: Use AppleScript to open the calendar to the event's date
        let script = """
            tell application "Calendar"
                activate
                view calendar at date "\(formatDateForAppleScript(event.startDate))"
            end tell
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if error == nil {
            logger.info("Opened calendar event using AppleScript")
        } else {
            logger.warning("AppleScript failed, opening Calendar app: \(error?.description ?? "")")
            // Method 2: Just open Calendar app
            openCalendarApp()
        }
    }
    
    private func formatDateForAppleScript(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy"
        return formatter.string(from: date)
    }
    
    private func openCalendarApp() {
        // Method 3: Just open the Calendar app
        if let calendarApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.open(calendarApp)
            logger.info("Opened Calendar app as fallback")
        } else {
            logger.error("Could not find Calendar app")
        }
    }
    
    // MARK: - Notifications
    
    @objc private func calendarChanged() {
        logger.info("Calendar database changed, refreshing events...")
        Task {
            await loadEvents(force: true)
        }
    }
    
    // MARK: - Utility
    
    func getEventById(_ eventId: String) -> CalendarEvent? {
        return events.first { $0.id == eventId }
    }
}

// MARK: - Logger Extension

extension AppLogger {
    static let calendarManager = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.trace.app",
        category: "CalendarManager"
    )
}
