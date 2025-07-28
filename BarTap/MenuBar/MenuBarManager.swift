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
    
    deinit {
        refreshWorkItem?.cancel()
    }
    
    /// Public function to dispatch app scanning
    func refreshApps(completion: (() -> Void)? = nil) {
        isScanning  = true
        lastScannedDate = Date()
        
        // Async dispatch to scan applications in the background
        // Use weak self to prevent retain cycles on complete refresh
        DispatchQueue.global(qos: .background).async { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                let apps = self.scanForMenuBarApps()
                
                DispatchQueue.main.async { [weak self] in
                    self?.detectedApps = apps
                    self?.isScanning = false
                    
                    // If a completion function is provided, execute
                    completion?()
                }
            }
        }
    }
    
    // MARK: - App Interactions
    
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
    
    /// Add app handler for background observation
    func addApp(_ app: NSRunningApplication) async {
        //let appMenuBoundaryX = onMain { getCachedAppMenuBoundaryX() }
        
        let children  = await Task.detached {
            //self.createMenuBarApps(for: app, appMenuBoundaryX: appMenuBoundaryX)
            self.createMenuBarApps(for: app, appMenuBoundaryX: nil)
        }.value
        
        onMain { detectedApps.removeAll { $0.processIdentifier == app.processIdentifier } }
        onMain { detectedApps.append(contentsOf: children) }
    }
    
    /// Remove app handler for background observation
    func removeApp(forPID pid: pid_t) {
        onMain { detectedApps.removeAll { $0.processIdentifier == pid } }
    }

    // MARK: - App Scanning
    
    /// Perform a full scan of the menu bar for applications using the Accessibility API
    private func scanForMenuBarApps() -> [MenuBarApp] {
        var foundApps: [MenuBarApp] = []
        let runningApps = onMain { NSWorkspace.shared.runningApplications }
        
        // Calculate the frontmost app's menu boundary ONCE before the loop
        // to avoid recalculating it for every single menu item
        //let appMenuBoundaryX = onMain { getCachedAppMenuBoundaryX() }
        
        // Each app can have one or more child apps in the menu bar
        // (e.g. Control Center -> [WiFi, Sound, etc.])
        for app in runningApps {
            autoreleasepool {
                //let childApps = createMenuBarApps(for: app, appMenuBoundaryX: appMenuBoundaryX)
                let childApps = createMenuBarApps(for: app, appMenuBoundaryX: nil)
                foundApps.append(contentsOf: childApps)
            }
        }
        
        return foundApps
    }
    
    /// Given an application, find all child menu bar apps and process
    private func createMenuBarApps(for app: NSRunningApplication, appMenuBoundaryX: CGFloat?) -> [MenuBarApp] {
        var childApps: [MenuBarApp] = []
        
        let policy = onMain { app.activationPolicy }
        guard policy == .accessory || policy == .regular else { return childApps }
        
        // Get the current application as an accessibility object and check for
        // 'ExtrasMenuBar' as this was identified as denoting a 'menu bar icon'
        let appElement = onMain { AXUIElementCreateApplication(app.processIdentifier) }
        
        var extrasMenuBarRaw: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, "AXExtrasMenuBar" as CFString, &extrasMenuBarRaw)
        guard result == .success, let raw = extrasMenuBarRaw,
              CFGetTypeID(raw) == AXUIElementGetTypeID() else { return childApps }
        let extrasMenuBarElement = raw as! AXUIElement
        
        var childrenRaw: AnyObject?
        let childrenResult = AXUIElementCopyAttributeValue(extrasMenuBarElement, kAXChildrenAttribute as CFString, &childrenRaw)
        guard childrenResult == .success,
              let children = childrenRaw as? [AXUIElement] else { return childApps }
        
        // Pull all AppKit properties
        let bundleId      = onMain { app.bundleIdentifier } ?? "unknown-app"
        let processId     = onMain { app.processIdentifier }
        let bundleURL     = onMain { app.bundleURL }
        let localizedName = onMain { app.localizedName } ?? "Unknown"
        var appTitle      = localizedName
        
        for child in children {
            // Nested release each application object as we iterate
            autoreleasepool {
                var sfSymbolName: String? = nil
                var iconPath:     String? = nil
                
                if localizedName == "Control Center" {
                    appTitle      = getMenuBarItemName(child, appName: localizedName)
                    sfSymbolName  = getControlCenterIcon(appName: appTitle)
                }
                
                // Icon cache lookup/creation
                iconPath = IconCacheManager.state.getCachedIcon(for: bundleId, appURL: bundleURL)
                if iconPath == nil, let icon = (onMain { app.icon }) {
                    iconPath = IconCacheManager.state.cacheIcon(icon: icon, for: bundleId, from: bundleURL)
                }
                
                // Build the app model & append
                //let obscured = isMenuBarItemObscured(child, appMenuBoundaryX: appMenuBoundaryX)
                let resolvedBundleId = getMenuBarBundleIdentifier(child, bundleIdentifier: bundleId)
                
                var model = MenuBarApp(
                    id: UUID(),
                    name: appTitle,
                    bundleIdentifier: resolvedBundleId,
                    processIdentifier: processId,
                    iconPath: iconPath,
                    sfSymbolName: sfSymbolName
                )
                
                //model.isObscured = obscured
                model.axElement  = child
                childApps.append(model)
            }
        }
        
        return childApps
    }
}
