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
    @State private var cacheRefreshMessage = ""
    @State private var showingUsageResetAlert = false

    private var appVersion: String {
        AppConstants.version
    }

    private var buildNumber: String {
        AppConstants.build
    }

    var body: some View {
        NativeSettingsPane {
            NativeSettingsSection("") {
                VStack(spacing: 6) {
                    // App Icon and Info
                    VStack(spacing: 6) {
                        VStack(spacing: 8) {
                            Text("Trace")
                                .font(.system(size: 24, weight: .semibold))

                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }


                    // Developer Info and Links
                    VStack(spacing: 8) {
                        Text("Created by Arjun Komath")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        HStack(spacing: 20) {
                            if let githubURL = URL(string: "https://github.com/arjunkomath") {
                                Link("GitHub", destination: githubURL)
                                    .font(.system(size: 12))
                            }

                            if let twitterURL = URL(string: "https://twitter.com/arjunz") {
                                Link("Twitter / X", destination: twitterURL)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            NativeSettingsSection("Data") {
                NativeSettingsRow(
                    title: "Data Location",
                    subtitle: dataPath,
                    minHeight: 66
                ) {
                    Button(action: openDataFolder) {
                        Text("Open")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Application Cache",
                    subtitle: "Rescan discovered apps and icons"
                ) {
                    Button(action: refreshAppCache) {
                        Text("Refresh")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Reset Onboarding",
                    subtitle: "Show welcome tutorial on next app launch"
                ) {
                    Button(action: resetOnboarding) {
                        Text("Reset")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Usage Data",
                    subtitle: "Clear app usage statistics and search history"
                ) {
                    Button(action: resetUsageData) {
                        Text("Reset")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            loadDebugInfo()
        }
        .alert("Onboarding Reset", isPresented: $showingResetAlert) {
            Button("OK") { }
        } message: {
            Text("The welcome tutorial will be shown when you next launch the app.")
        }
        .alert("Application Refresh", isPresented: $showingCacheRefreshAlert) {
            Button("OK") { }
        } message: {
            Text(cacheRefreshMessage)
        }
        .alert("Usage Data Cleared", isPresented: $showingUsageResetAlert) {
            Button("OK") { }
        } message: {
            Text("All usage statistics and search history have been cleared.")
        }
    }

    private func loadDebugInfo() {
        // Get data path using centralized app data directory
        dataPath = AppConstants.appDataDirectory.path
    }

    private func refreshAppCache() {
        let services = ServiceContainer.shared
        services.appSearchManager.refreshCache()
        cacheRefreshMessage = "Trace is rebuilding the application list and icon cache in the background."
        showingCacheRefreshAlert = true
    }

    private func openDataFolder() {
        let directory = AppConstants.appDataDirectory
        let fileManager = FileManager.default

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        NSWorkspace.shared.open(directory)
    }

    private func resetOnboarding() {
        // Reset the onboarding flag using SettingsManager
        SettingsManager.shared.updateOnboardingCompleted(false)
        showingResetAlert = true
    }

    private func resetUsageData() {
        // Clear usage data using UsageTracker
        UsageTracker.shared.clearUsageData()
        showingUsageResetAlert = true
    }

}
