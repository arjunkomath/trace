//
//  Constants.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Foundation
import CoreGraphics

enum AppConstants {
    /// The app's bundle identifier, dynamically retrieved from the main bundle
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.techulus.trace"
    enum Window {
        static let launcherWidth: CGFloat = 750
        static let launcherHeight: CGFloat = 60
        static let maxResultsHeight: CGFloat = 320
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 12
        static let shadowOffset = CGSize(width: 0, height: 6)
        static let searchPadding: CGFloat = 30
        
        static let settingsWidth: CGFloat = 550
        static let settingsHeight: CGFloat = 650
    }
    
    enum Search {
        static let defaultLimit = 10
        static let refreshInterval: TimeInterval = 60.0
        static let iconSize = CGSize(width: 24, height: 24)
    }
    
    enum Hotkey {
        static let defaultKeyCode: UInt32 = 49 // Space key
        static let commaKeyCode: CGKeyCode = 0x2B
    }
    
    enum Animation {
        static let focusDelay: TimeInterval = 0.05
        static let settingsDelay: TimeInterval = 0.1
    }
    
    enum Paths {
        static let applications = [
            "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices/Applications",
            "/usr/local",
            "~/Applications",
        ]
    }
}
