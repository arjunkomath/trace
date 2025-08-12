//
//  ToastManager.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Foundation
import AppKit

class ToastManager {
    static let shared = ToastManager()
    
    private var toastQueue: [(message: String, type: ToastType)] = []
    private var currentToast: ToastWindow?
    private var isShowingToast = false
    private let queueLock = NSLock()
    
    private init() {}
    
    // MARK: - Public API
    
    func showToast(_ message: String, type: ToastType = .info) {
        queueLock.lock()
        toastQueue.append((message, type))
        queueLock.unlock()
        
        processQueue()
    }
    
    func showSuccess(_ message: String) {
        showToast(message, type: .success)
    }
    
    func showError(_ message: String) {
        showToast(message, type: .error)
    }
    
    func showWarning(_ message: String) {
        showToast(message, type: .warning)
    }
    
    func showInfo(_ message: String) {
        showToast(message, type: .info)
    }
    
    // MARK: - Private Methods
    
    private func processQueue() {
        guard !isShowingToast else { return }
        
        queueLock.lock()
        guard !toastQueue.isEmpty else {
            queueLock.unlock()
            return
        }
        
        let toast = toastQueue.removeFirst()
        queueLock.unlock()
        
        showNextToast(message: toast.message, type: toast.type)
    }
    
    private func showNextToast(message: String, type: ToastType) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isShowingToast = true
            
            // Create and show toast window
            let toastWindow = ToastWindow(message: message, type: type)
            self.currentToast = toastWindow
            toastWindow.show()
            
            // Auto-hide after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                self?.hideCurrentToast()
            }
        }
    }
    
    private func hideCurrentToast() {
        currentToast?.hide()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.currentToast = nil
            self?.isShowingToast = false
            self?.processQueue()
        }
    }
    
    // MARK: - Convenience Methods for Common Messages
    
    func showActionExecuted(_ action: String) {
        showInfo(action)
    }
    
    func showNetworkError() {
        showError("Network connection failed")
    }
    
    func showPermissionRequired(_ permission: String) {
        showWarning("\(permission) permission required")
    }
}
