//
//  ServiceContainer.swift
//  trace
//
//  Created by Arjun on 9/8/2025.
//

import Foundation

/// Dependency injection container for managing app services
class ServiceContainer: ObservableObject {
    // MARK: - Core Services
    private var _appSearchManager: AppSearchManager?
    private var _windowManager: WindowManager?
    private var _usageTracker: UsageTracker?
    private var _hotkeyRegistry: HotkeyRegistry?
    private var _appHotkeyManager: AppHotkeyManager?
    private var _windowHotkeyManager: WindowHotkeyManager?
    private var _settingsService: SettingsService?
    private var _folderManager: FolderManager?
    private var _permissionManager: PermissionManager?
    
    // MARK: - Service Accessors
    
    var appSearchManager: AppSearchManager {
        if let manager = _appSearchManager {
            return manager
        }
        let manager = AppSearchManager(usageTracker: usageTracker)
        _appSearchManager = manager
        return manager
    }
    
    var windowManager: WindowManager {
        if let manager = _windowManager {
            return manager
        }
        let manager = WindowManager.shared // Use existing singleton temporarily
        _windowManager = manager
        return manager
    }
    
    var usageTracker: UsageTracker {
        if let tracker = _usageTracker {
            return tracker
        }
        let tracker = UsageTracker.shared // Use existing singleton temporarily
        _usageTracker = tracker
        return tracker
    }
    
    var hotkeyRegistry: HotkeyRegistry {
        if let registry = _hotkeyRegistry {
            return registry
        }
        let registry = HotkeyRegistry.shared // Use existing singleton temporarily
        _hotkeyRegistry = registry
        return registry
    }
    
    var appHotkeyManager: AppHotkeyManager {
        if let manager = _appHotkeyManager {
            return manager
        }
        let manager = AppHotkeyManager.shared // Use existing singleton temporarily
        _appHotkeyManager = manager
        return manager
    }
    
    var windowHotkeyManager: WindowHotkeyManager {
        if let manager = _windowHotkeyManager {
            return manager
        }
        let manager = WindowHotkeyManager.shared // Use existing singleton temporarily
        _windowHotkeyManager = manager
        return manager
    }
    
    var settingsService: SettingsService {
        if let service = _settingsService {
            return service
        }
        let service = SettingsService()
        _settingsService = service
        return service
    }
    
    var folderManager: FolderManager {
        if let manager = _folderManager {
            return manager
        }
        let manager = FolderManager()
        _folderManager = manager
        return manager
    }
    
    var permissionManager: PermissionManager {
        if let manager = _permissionManager {
            return manager
        }
        let manager = PermissionManager.shared // Use existing singleton
        _permissionManager = manager
        return manager
    }
    
    // MARK: - Lifecycle
    
    func shutdown() {
        _appSearchManager?.shutdown()
        _windowManager = nil
        _usageTracker = nil
        _hotkeyRegistry = nil
        _appHotkeyManager = nil
        _windowHotkeyManager = nil
        _settingsService = nil
        _folderManager = nil
        _permissionManager = nil
    }
}

/// Global service container - only used at app level
private var globalServiceContainer: ServiceContainer?

extension ServiceContainer {
    static var shared: ServiceContainer {
        if let container = globalServiceContainer {
            return container
        }
        let container = ServiceContainer()
        globalServiceContainer = container
        return container
    }
    
    /// For testing - allows injecting a custom container
    static func setShared(_ container: ServiceContainer) {
        globalServiceContainer = container
    }
}