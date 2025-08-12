//
//  AppIconView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI

struct AppIconView: View {
    let bundleIdentifier: String
    @State private var icon: NSImage?
    @State private var loadingTask: Task<Void, Never>?
    
    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadIcon()
        }
        .onChange(of: bundleIdentifier) { _, newBundleId in
            // Cancel existing task and reload when bundle identifier changes
            loadingTask?.cancel()
            icon = nil
            loadIcon()
        }
        .onDisappear {
            loadingTask?.cancel()
        }
    }
    
    private func loadIcon() {
        loadingTask?.cancel()
        
        let services = ServiceContainer.shared
        guard let app = services.appSearchManager.getApp(by: bundleIdentifier) else { return }
        
        loadingTask = Task { [bundleIdentifier] in
            let loadedIcon = await services.appSearchManager.getAppIcon(for: app)
            
            // Only update if this task hasn't been cancelled and bundle ID hasn't changed
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                // Double-check bundle identifier hasn't changed while loading
                if self.bundleIdentifier == bundleIdentifier {
                    self.icon = loadedIcon
                }
            }
        }
    }
}