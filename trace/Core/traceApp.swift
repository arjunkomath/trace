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
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
