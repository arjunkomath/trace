//
//  traceApp.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI

@main
struct traceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
        TraceTheme.runContrastSelfCheck()
        #endif
    }
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
