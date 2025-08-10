//
//  OnboardingView.swift
//  trace
//
//  Created by Claude on 8/10/2025.
//

import SwiftUI
import AppKit

struct OnboardingView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var currentStep = 0
    @State private var isAnimating = false
    
    let onComplete: () -> Void
    
    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "filemenu.and.selection",
            title: "Welcome to Trace",
            description: "A powerful system-wide launcher for macOS. Search apps, manage windows, and execute commands instantly.",
            primaryColor: .blue
        ),
        OnboardingStep(
            icon: "keyboard",
            title: "Global Hotkey",
            description: "Press ⌥Space anywhere to open Trace. You can customize this hotkey in settings.",
            primaryColor: .green
        ),
        OnboardingStep(
            icon: "magnifyingglass",
            title: "Smart Search",
            description: "Find apps, system commands, window positions, and more. Type to search or browse suggestions.",
            primaryColor: .orange
        ),
        OnboardingStep(
            icon: "gearshape",
            title: "Customize Everything",
            description: "Configure hotkeys, manage folders, set app shortcuts, and control window positions from settings.",
            primaryColor: .purple
        )
    ]
    
    var body: some View {
        ZStack {
            // Backdrop
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main content area
                VStack(spacing: 32) {
                    // Progress indicator
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            Circle()
                                .fill(index <= currentStep ? steps[currentStep].primaryColor : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentStep ? 1.2 : 1.0)
                                .animation(.spring(response: 0.4), value: currentStep)
                        }
                    }
                    .padding(.top, 24)
                    
                    // Step content
                    VStack(spacing: 24) {
                        // Icon
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(steps[currentStep].primaryColor)
                            .scaleEffect(isAnimating ? 1.0 : 0.8)
                            .opacity(isAnimating ? 1.0 : 0.6)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isAnimating)
                        
                        // Title
                        Text(steps[currentStep].title)
                            .font(.system(size: 28, weight: .semibold))
                            .multilineTextAlignment(.center)
                        
                        // Description
                        Text(steps[currentStep].description)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 400)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
                
                // Controls
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                                triggerAnimation()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if currentStep < steps.count - 1 {
                        Button("Next") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                                triggerAnimation()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button("Get Started") {
                            onComplete()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 500, height: 400)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.15), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.3),
            radius: 20,
            x: 0,
            y: 8
        )
        .onAppear {
            triggerAnimation()
        }
        .onKeyPress(.escape) {
            onComplete()
            return .handled
        }
    }
    
    private func triggerAnimation() {
        isAnimating = false
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            isAnimating = true
        }
    }
}

private struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
    let primaryColor: Color
}

// MARK: - Onboarding Window

class OnboardingWindow: NSWindow {
    private let onComplete: () -> Void
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContent()
    }
    
    private func setupWindow() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isMovableByWindowBackground = true
        
        center()
    }
    
    private func setupContent() {
        let hostingView = NSHostingView(
            rootView: OnboardingView(onComplete: onComplete)
                .environment(\.openSettings, OpenSettingsEnvironmentAction {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.showPreferences()
                    }
                })
        )
        
        contentView = hostingView
    }
    
    func show() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hide() {
        orderOut(nil)
    }
}

// MARK: - Environment Actions

struct OpenSettingsEnvironmentAction {
    let action: () -> Void
    
    func callAsFunction() {
        action()
    }
}

extension EnvironmentValues {
    private struct OpenSettingsKey: EnvironmentKey {
        static let defaultValue = OpenSettingsEnvironmentAction { }
    }
    
    var openSettings: OpenSettingsEnvironmentAction {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .preferredColorScheme(.dark)
}