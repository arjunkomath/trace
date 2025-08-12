//
//  AboutSettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import Sparkle

struct AboutSettingsView: View {
    @State private var dataPath: String = ""
    @State private var showingResetAlert = false
    @State private var showingCacheRefreshAlert = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    // App Icon and Info
                    VStack(spacing: 6) {
                        VStack(spacing: 8) {
                            Text("Trace")
                                .font(.system(size: 24, weight: .semibold))
                            
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Text("Spotlight alternative and shortcut toolkit for macOS")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    
                    
                    // Developer Info and Links
                    VStack(spacing: 8) {
                        Text("Created by Arjun Komath & Claude")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            if let githubURL = URL(string: "https://github.com/arjunkomath") {
                                Link("GitHub", destination: githubURL)
                                    .font(.system(size: 12))
                            }
                            
                            if let twitterURL = URL(string: "https://twitter.com/arjunz") {
                                Link("Twitter", destination: twitterURL)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            
            // Data Storage Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // Storage Path
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Data Location")
                                .font(.system(size: 13, weight: .medium))
                            Text(dataPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        
                        Spacer()
                        
                        Button(action: openDataFolder) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                Text("Open")
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                    }
                    
                }
                .padding(.vertical, 4)
            } header: {
                Text("Storage")
            }
            
            // Reset Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Application Cache")
                            .font(.system(size: 13, weight: .medium))
                        Text("Refresh discovered apps and icons")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: refreshAppCache) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset Onboarding")
                            .font(.system(size: 13, weight: .medium))
                        Text("Show welcome tutorial on next app launch")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: resetOnboarding) {
                        HStack(spacing: 4) {
                            Image(systemName: "graduationcap")
                            Text("Reset")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Reset")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadDebugInfo()
        }
        .alert("Onboarding Reset", isPresented: $showingResetAlert) {
            Button("OK") { }
        } message: {
            Text("The welcome tutorial will be shown when you next launch the app.")
        }
        .alert("Cache Refreshed", isPresented: $showingCacheRefreshAlert) {
            Button("OK") { }
        } message: {
            Text("Application cache has been refreshed successfully.")
        }
    }
    
    private func loadDebugInfo() {
        // Get data path
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let traceDirectory = appSupport.appendingPathComponent("Trace", isDirectory: true)
            dataPath = traceDirectory.path
        }
    }
    
    private func refreshAppCache() {
        // Trigger app cache refresh through ServiceContainer
        let services = ServiceContainer.shared
        services.appSearchManager.refreshCache()
        showingCacheRefreshAlert = true
    }
    
    private func openDataFolder() {
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let traceDirectory = appSupport.appendingPathComponent("Trace", isDirectory: true)
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: traceDirectory.path) {
                try? fileManager.createDirectory(at: traceDirectory, withIntermediateDirectories: true)
            }
            
            NSWorkspace.shared.open(traceDirectory)
        }
    }
    
    private func resetOnboarding() {
        // Reset the onboarding flag using SettingsManager
        SettingsManager.shared.updateOnboardingCompleted(false)
        showingResetAlert = true
    }
    
}
