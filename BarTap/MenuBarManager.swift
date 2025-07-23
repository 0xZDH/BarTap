//
//  MenuBarManager.swift
//  BarTap
//

import SwiftUI
import os

/// Menu bar manager to handle scanning for applications and storing
/// them in-memory
class MenuBarManager: NSObject, ObservableObject {
    @Published var detectedApps: [MenuBarApp] = []
    @Published var isScanning: Bool = false
    
    private var refreshWorkItem: DispatchWorkItem?
    private let logger = Logger(subsystem: "io.github.0xZDH.BarTap", category: "MenuBarManager")
    
    var lastScannedDate: Date? // Keep public to allow refreshing based on last scanned
    var lastScannedTimestamp: String {
        guard let date = lastScannedDate else { return "Last scanned: never" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        
        return "Last scanned: \(formatter.string(from: date))"
    }
    
    override init() {
        super.init()
        
        // Add observers to automatically refresh when apps are launched or quit
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(
            self,
            selector: #selector(scheduleRefresh),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(scheduleRefresh),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        refreshWorkItem?.cancel()
    }
    
    /// Public function to dispatch app scanning
    func refreshApps() {
        isScanning  = true
        lastScannedDate = Date()
        
        // Async dispatch to scan applications in the background
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                let apps = self.scanForMenuBarApps()
                
                DispatchQueue.main.async {
                    self.detectedApps = apps
                    self.isScanning = false
                }
            }
        }
    }
}

// MARK: - Private Helper Functions

/// MenuBarManager extension to maintain private functions
extension MenuBarManager {
    /// Schedules a debounced refresh of the app list
    /// This prevents multiple rapid refreshes when several apps launch or quit at once
    @objc private func scheduleRefresh() {
        refreshWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshApps()
        }
        
        refreshWorkItem = workItem
        
        // Debounce for 1 second to avoid excessive scanning
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    /// Scan the menu bar for applications using the Accessibility API
    private func scanForMenuBarApps() -> [MenuBarApp] {
        var foundApps: [MenuBarApp] = []
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Calculate the frontmost app's menu boundary ONCE before the loop
        // to avoid recalculating it for every single menu item
        let appMenuBoundaryX = getActiveAppMenuBoundaryX()
        
        for app in runningApps {
            guard app.activationPolicy == .accessory || app.activationPolicy == .regular else { continue }
            
            // Get the current application as an accessibility object and check for
            // 'ExtrasMenuBar' as this was identified as denoting a 'menu bar icon'
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            
            var extrasMenuBarRaw: AnyObject?
            let extrasMenuBarResult = AXUIElementCopyAttributeValue(appElement, "AXExtrasMenuBar" as CFString, &extrasMenuBarRaw)
            
            if extrasMenuBarResult == .success, let extrasMenuBarValue = extrasMenuBarRaw {
                //let extrasMenuBarElement = unsafeBitCast(extrasMenuBarValue, to: AXUIElement.self)
                let extrasMenuBarElement = extrasMenuBarValue as! AXUIElement
                
                // Get the menu bar items for this app -> Some applications have several
                // (e.g. Control Center)
                var childrenRaw: AnyObject?
                let childrenResult = AXUIElementCopyAttributeValue(extrasMenuBarElement, kAXChildrenAttribute as CFString, &childrenRaw)
                
                if childrenResult == .success, let children = childrenRaw as? [AXUIElement] {
                    for child in children {
                        var appTitle:    String
                        var appIconPath: String?
                        var appSFSymbol: String?
                        
                        if app.localizedName == "Control Center" {
                            appTitle    = getMenuBarItemName(child, appName: app.localizedName ?? "Unknown")
                            appSFSymbol = getControlCenterIcon(appName: appTitle)
                            
                            if let appIcon = app.icon {
                                appIconPath = IconCacheManager.state.cacheIcon(icon: appIcon, for: app.bundleIdentifier ?? "unknown-cc-app", from: app.bundleURL)
                            }
                        } else {
                            appTitle    = app.localizedName ?? "Unknown"
                            appSFSymbol = nil
                            
                            if let appIcon = app.icon {
                                appIconPath = IconCacheManager.state.cacheIcon(icon: appIcon, for: app.bundleIdentifier ?? "unknown-app", from: app.bundleURL)
                            }
                        }
                        
                        let appIsObscured = isMenuBarItemObscured(child, appMenuBoundaryX: appMenuBoundaryX)
                        let appBundleId   = getMenuBarBundleIdentifier(child, bundleIdentifier: app.bundleIdentifier ?? "unknown")
                        
                        var menuBarApp = MenuBarApp(
                            id: UUID(),
                            name: appTitle,
                            bundleIdentifier: appBundleId,
                            processIdentifier: app.processIdentifier,
                            iconPath: appIconPath,
                            sfSymbolName: appSFSymbol
                        )
                        
                        // Store the accessibility element for later interaction
                        menuBarApp.isObscured = appIsObscured
                        menuBarApp.axElement  = child
                        foundApps.append(menuBarApp)
                    }
                }
            }
        }
        
        return foundApps
    }
    
    /// Handler to 'launch' a given application
    func launchApp(_ app: MenuBarApp) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    /// Handler to quit a given application
    func quitApp(_ app: MenuBarApp) {
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == app.processIdentifier }) {
            runningApp.terminate()
        }
    }
    
    /// Handler to provide a 'click simulation'
    func clickMenuBarApp(_ app: MenuBarApp) {
        guard let axElement = app.axElement else {
            logger.error("No accessibility element stored for \(app.name)")
            return
        }
        
        // Try the press action first
        let pressResult = AXUIElementPerformAction(axElement, kAXPressAction as CFString)
        
        if pressResult == .success {
            return
        }
        
        // If press doesn't work, try other common actions
        let actionsToTry = [
            "AXPress"         as CFString, // Fallback for kAXPressAction
            kAXShowMenuAction as CFString,
            "AXShowMenu"      as CFString, // Fallback for kAXShowMenuAction
            "AXMenuOpen"      as CFString,
            "AXClick"         as CFString,
            "AXLeftClick"     as CFString
        ]
        
        for action in actionsToTry {
            let result = AXUIElementPerformAction(axElement, action)
            if result == .success {
                return
            }
        }
        
        logger.error("Failed to interact with \(app.name) - no valid actions worked")
        
        // Debug: List available actions using the correct API
        var actionsRaw: CFArray?
        let actionsResult = AXUIElementCopyActionNames(axElement, &actionsRaw)
        
        if actionsResult == .success, let actions = actionsRaw as? [String] {
            logger.debug("Available actions for \(app.name): \(actions)")
        }
    }
}
