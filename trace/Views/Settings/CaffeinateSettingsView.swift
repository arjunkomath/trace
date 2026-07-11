//
//  CaffeinateSettingsView.swift
//  trace
//
//  Created by Arjun on 5/27/2026.
//

import SwiftUI

struct CaffeinateSettingsView: View {
    @State private var caffeinateActive = false
    @State private var startCaffeinateOnLaunch = false
    @State private var stopCaffeinateOnSleep = false
    @State private var keepDisplayAwake = true
    @State private var preventIdleSleep = true
    @State private var preventDiskSleep = true
    @State private var preventSystemSleepOnPower = true
    @State private var declareUserActive = false
    @State private var useCaffeinateTimeout = false
    @State private var timeoutPreset: CaffeinateTimeoutPreset = .oneHour
    @State private var customTimeoutMinutes = 60
    @FocusState private var customTimeoutFocused: Bool
    @ObservedObject private var settingsManager = SettingsManager.shared

    var body: some View {
        NativeSettingsPane {
            NativeSettingsSection("Keep Awake") {
                NativeSettingsRow(
                    title: "Command",
                    subtitle: "Built automatically from your choices"
                ) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(caffeinateActive ? Color.green : Color.secondary.opacity(0.45))
                            .frame(width: 7, height: 7)

                        Text(caffeinateCommandPreview)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(width: 220, alignment: .trailing)

                        Button {
                            resetCaffeinateOptions()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Reset Caffeinate options")
                        .disabled(caffeinateFlagsPreview == CaffeinateManager.defaultFlags)
                    }
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Start on Launch",
                    subtitle: "Automatically start Caffeinate when Trace opens"
                ) {
                    Toggle("", isOn: $startCaffeinateOnLaunch)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityLabel(Text("Start on Launch"))
                        .onChange(of: startCaffeinateOnLaunch) { _, enabled in
                            settingsManager.updateStartCaffeinateOnLaunch(enabled)
                        }
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Stop When Mac Sleeps",
                    subtitle: "Turns off Caffeinate when macOS sleeps; it stays off after wake"
                ) {
                    Toggle("", isOn: $stopCaffeinateOnSleep)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityLabel(Text("Stop When Mac Sleeps"))
                        .onChange(of: stopCaffeinateOnSleep) { _, enabled in
                            settingsManager.updateStopCaffeinateOnSleep(enabled)
                        }
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Keep Display On",
                    subtitle: "Prevents the screen from dimming or turning off"
                ) {
                    Toggle("", isOn: $keepDisplayAwake)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .onChange(of: keepDisplayAwake) { _, _ in
                            saveCaffeinateOptions()
                        }
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Keep Mac Awake",
                    subtitle: "Prevents sleep when your Mac has been idle"
                ) {
                    Toggle("", isOn: $preventIdleSleep)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .onChange(of: preventIdleSleep) { _, _ in
                            saveCaffeinateOptions()
                        }
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Keep Disks Ready",
                    subtitle: "Prevents attached disks from entering low-power idle mode"
                ) {
                    Toggle("", isOn: $preventDiskSleep)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .onChange(of: preventDiskSleep) { _, _ in
                            saveCaffeinateOptions()
                        }
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Stay Awake on Power Adapter",
                    subtitle: "Helps prevent sleep while connected to power"
                ) {
                    Toggle("", isOn: $preventSystemSleepOnPower)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .onChange(of: preventSystemSleepOnPower) { _, _ in
                            saveCaffeinateOptions()
                        }
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Nudge Activity",
                    subtitle: "Briefly tells macOS you are active; can wake the display"
                ) {
                    Toggle("", isOn: $declareUserActive)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .onChange(of: declareUserActive) { _, _ in
                            saveCaffeinateOptions()
                        }
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Duration",
                    subtitle: useCaffeinateTimeout ? "Stops after \(timeoutDurationDescription)" : "Runs until you stop it or quit Trace",
                    minHeight: useCaffeinateTimeout && timeoutPreset == .custom ? 74 : 54
                ) {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 8) {
                            Toggle("", isOn: $useCaffeinateTimeout)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .onChange(of: useCaffeinateTimeout) { _, _ in
                                    saveCaffeinateOptions()
                                }

                            Picker("", selection: $timeoutPreset) {
                                ForEach(CaffeinateTimeoutPreset.allCases) { preset in
                                    Text(preset.title).tag(preset)
                                }
                            }
                            .pickerStyle(.menu)
                            .controlSize(.small)
                            .frame(width: 122)
                            .disabled(!useCaffeinateTimeout)
                            .onChange(of: timeoutPreset) { _, _ in
                                saveCaffeinateOptions()
                            }
                        }

                        if useCaffeinateTimeout && timeoutPreset == .custom {
                            HStack(spacing: 5) {
                                TextField("", value: $customTimeoutMinutes, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 54)
                                    .focused($customTimeoutFocused)
                                    .onSubmit {
                                        commitCustomTimeoutMinutes()
                                    }
                                    .onChange(of: customTimeoutFocused) { _, isFocused in
                                        if !isFocused {
                                            commitCustomTimeoutMinutes()
                                        }
                                    }

                                Text("min")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            caffeinateActive = ServiceContainer.shared.caffeinateManager.isActive
            startCaffeinateOnLaunch = settingsManager.settings.startCaffeinateOnLaunch
            stopCaffeinateOnSleep = settingsManager.settings.stopCaffeinateOnSleep
            loadCaffeinateOptions()
        }
        .onReceive(NotificationCenter.default.publisher(for: CaffeinateManager.statusDidChangeNotification)) { _ in
            caffeinateActive = ServiceContainer.shared.caffeinateManager.isActive
        }
    }

    private var caffeinateFlagsPreview: String {
        currentCaffeinateOptions().flagsText
    }

    private var caffeinateCommandPreview: String {
        "/usr/bin/caffeinate \(caffeinateFlagsPreview)"
    }

    private var timeoutSecondsForSelection: Int {
        if let presetSeconds = timeoutPreset.seconds {
            return presetSeconds
        }

        return min(max(customTimeoutMinutes, 1), 1_440) * 60
    }

    private var timeoutDurationDescription: String {
        CaffeinateTimeoutPreset.durationDescription(for: timeoutSecondsForSelection)
    }

    private func loadCaffeinateOptions() {
        let options = CaffeinateOptions(flagsText: settingsManager.settings.caffeinateFlags)

        keepDisplayAwake = options.keepDisplayAwake
        preventIdleSleep = options.preventIdleSleep
        preventDiskSleep = options.preventDiskSleep
        preventSystemSleepOnPower = options.preventSystemSleepOnPower
        declareUserActive = options.declareUserActive
        useCaffeinateTimeout = options.useTimeout
        timeoutPreset = CaffeinateTimeoutPreset.matching(seconds: options.timeoutSeconds) ?? .custom
        customTimeoutMinutes = min(max((options.timeoutSeconds + 59) / 60, 1), 1_440)
    }

    private func currentCaffeinateOptions() -> CaffeinateOptions {
        CaffeinateOptions(
            keepDisplayAwake: keepDisplayAwake,
            preventIdleSleep: preventIdleSleep,
            preventDiskSleep: preventDiskSleep,
            preventSystemSleepOnPower: preventSystemSleepOnPower,
            declareUserActive: declareUserActive,
            useTimeout: useCaffeinateTimeout,
            timeoutSeconds: timeoutSecondsForSelection
        )
    }

    private func saveCaffeinateOptions() {
        if timeoutPreset == .custom {
            customTimeoutMinutes = min(max(customTimeoutMinutes, 1), 1_440)
        }

        let options = currentCaffeinateOptions()
        settingsManager.updateCaffeinateFlags(options.flagsText)

        if caffeinateActive {
            ServiceContainer.shared.caffeinateManager.stop()
            if ServiceContainer.shared.caffeinateManager.start() {
                ToastManager.shared.showInfo("Caffeinate restarted")
            }
        }
    }

    private func resetCaffeinateOptions() {
        let options = CaffeinateOptions(flagsText: CaffeinateManager.defaultFlags)

        keepDisplayAwake = options.keepDisplayAwake
        preventIdleSleep = options.preventIdleSleep
        preventDiskSleep = options.preventDiskSleep
        preventSystemSleepOnPower = options.preventSystemSleepOnPower
        declareUserActive = options.declareUserActive
        useCaffeinateTimeout = options.useTimeout
        timeoutPreset = CaffeinateTimeoutPreset.matching(seconds: options.timeoutSeconds) ?? .oneHour
        customTimeoutMinutes = min(max((options.timeoutSeconds + 59) / 60, 1), 1_440)
        saveCaffeinateOptions()
    }

    private func commitCustomTimeoutMinutes() {
        customTimeoutMinutes = min(max(customTimeoutMinutes, 1), 1_440)
        saveCaffeinateOptions()
    }
}

private enum CaffeinateTimeoutPreset: String, CaseIterable, Identifiable {
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    case eightHours
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fifteenMinutes:
            return "15 min"
        case .thirtyMinutes:
            return "30 min"
        case .oneHour:
            return "1 hour"
        case .twoHours:
            return "2 hours"
        case .fourHours:
            return "4 hours"
        case .eightHours:
            return "8 hours"
        case .custom:
            return "Custom"
        }
    }

    var seconds: Int? {
        switch self {
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .oneHour:
            return 60 * 60
        case .twoHours:
            return 2 * 60 * 60
        case .fourHours:
            return 4 * 60 * 60
        case .eightHours:
            return 8 * 60 * 60
        case .custom:
            return nil
        }
    }

    static func matching(seconds: Int) -> CaffeinateTimeoutPreset? {
        allCases.first { $0.seconds == seconds }
    }

    static func durationDescription(for seconds: Int) -> String {
        let minutes = max(seconds / 60, 1)

        if minutes < 60 {
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if remainingMinutes == 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }

        let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
        let minuteText = remainingMinutes == 1 ? "1 minute" : "\(remainingMinutes) minutes"
        return "\(hourText) \(minuteText)"
    }
}

private struct CaffeinateOptions {
    var keepDisplayAwake: Bool
    var preventIdleSleep: Bool
    var preventDiskSleep: Bool
    var preventSystemSleepOnPower: Bool
    var declareUserActive: Bool
    var useTimeout: Bool
    var timeoutSeconds: Int

    init(
        keepDisplayAwake: Bool,
        preventIdleSleep: Bool,
        preventDiskSleep: Bool,
        preventSystemSleepOnPower: Bool,
        declareUserActive: Bool,
        useTimeout: Bool,
        timeoutSeconds: Int
    ) {
        self.keepDisplayAwake = keepDisplayAwake
        self.preventIdleSleep = preventIdleSleep
        self.preventDiskSleep = preventDiskSleep
        self.preventSystemSleepOnPower = preventSystemSleepOnPower
        self.declareUserActive = declareUserActive
        self.useTimeout = useTimeout
        self.timeoutSeconds = min(max(timeoutSeconds, 60), 86_400)
    }

    init(flagsText: String) {
        self.init(
            keepDisplayAwake: false,
            preventIdleSleep: false,
            preventDiskSleep: false,
            preventSystemSleepOnPower: false,
            declareUserActive: false,
            useTimeout: false,
            timeoutSeconds: 3600
        )

        let arguments = (try? CaffeinateManager.arguments(from: flagsText))
            ?? (try? CaffeinateManager.arguments(from: CaffeinateManager.defaultFlags))
            ?? ["-dims"]

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]

            if argument == "-t", index + 1 < arguments.count {
                useTimeout = true
                timeoutSeconds = Int(arguments[index + 1]) ?? 3600
                index += 2
                continue
            }

            for flag in argument.dropFirst() {
                switch flag {
                case "d":
                    keepDisplayAwake = true
                case "i":
                    preventIdleSleep = true
                case "m":
                    preventDiskSleep = true
                case "s":
                    preventSystemSleepOnPower = true
                case "u":
                    declareUserActive = true
                default:
                    break
                }
            }

            index += 1
        }
    }

    var flagsText: String {
        var combinedFlags = "-"

        if keepDisplayAwake {
            combinedFlags.append("d")
        }
        if preventIdleSleep {
            combinedFlags.append("i")
        }
        if preventDiskSleep {
            combinedFlags.append("m")
        }
        if preventSystemSleepOnPower {
            combinedFlags.append("s")
        }
        if declareUserActive {
            combinedFlags.append("u")
        }

        var arguments: [String] = combinedFlags.count > 1 ? [combinedFlags] : ["-i"]

        if useTimeout {
            arguments.append("-t")
            arguments.append("\(timeoutSeconds)")
        }

        return arguments.joined(separator: " ")
    }
}
