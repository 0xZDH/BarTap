//
//  BarTapMenu.swift
//  BarTap
//

import SwiftUI

// MARK: - Data Models

struct MenuBarApp: Identifiable, Codable {
    let id: UUID
    let bundleIdentifier: String
    let name: String
    let processIdentifier: pid_t
    let iconData: Data?
    let sfSymbolName: String? // Icon fallback
    var lastSeen: Date
    var isObscured: Bool = false
    
    // This can't be Codable, so we'll handle it separately
    private var _axElement: AXUIElement?
    
    var axElement: AXUIElement? {
        get { _axElement }
        set { _axElement = newValue }
    }
    
    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.processIdentifier == processIdentifier }
    }
    
    // Custom initializer to handle the Date
    init(id: UUID, bundleIdentifier: String, name: String, processIdentifier: pid_t, iconData: Data?, sfSymbolName: String?) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.processIdentifier = processIdentifier
        self.iconData = iconData
        self.sfSymbolName = sfSymbolName
        self.lastSeen = Date() // Set current date when created
    }
    
    // Custom coding to handle the non-Codable AXUIElement
    enum CodingKeys: String, CodingKey {
        case id, bundleIdentifier, name, processIdentifier, iconData, sfSymbolName, lastSeen
    }
}

/// Menu bar manager to handle scanning for applications and storing
/// them in-memory
class MenuBarManager: ObservableObject {
    @Published var detectedApps: [MenuBarApp] = []
    @Published var isScanning: Bool = false
    
    func refreshApps() {
        isScanning = true
        
        // Async dispatch to scan applications in the background
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = self.scanForMenuBarApps()
            
            DispatchQueue.main.async {
                self.detectedApps = apps
                self.isScanning = false
            }
        }
    }
    
    /// Scan the menu bar for applications using the Accessibility API
    private func scanForMenuBarApps() -> [MenuBarApp] {
        var foundApps: [MenuBarApp] = []
        
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            guard app.activationPolicy == .accessory || app.activationPolicy == .regular else { continue }
            
            // Get the current application as an accessibility object and check for
            // 'ExtrasMenuBar' as this was identified as denoting a 'menu bar icon'
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var extrasMenuBarRaw: AnyObject?
            let extrasMenuBarResult = AXUIElementCopyAttributeValue(appElement, "AXExtrasMenuBar" as CFString, &extrasMenuBarRaw)

            if extrasMenuBarResult == .success, let extrasMenuBarValue = extrasMenuBarRaw {
                let extrasMenuBarElement = unsafeBitCast(extrasMenuBarValue, to: AXUIElement.self)

                // Get the menu bar items for this app -> Some applications have several
                // (e.g. Control Center)
                var childrenRaw: AnyObject?
                let childrenResult = AXUIElementCopyAttributeValue(extrasMenuBarElement, kAXChildrenAttribute as CFString, &childrenRaw)

                if childrenResult == .success, let children = childrenRaw as? [AXUIElement] {
                    for child in children {
                        // For applications that have multiple menu bar items, find
                        // the child application name
                        var appTitle:    String
                        var appIcon:     Data?
                        var appSFSymbol: String?
                        
                        if app.localizedName == "Control Center" {
                            appTitle    = getMenuBarItemName(child, appName: app.localizedName ?? "Unknown")
                            appIcon     = app.icon?.tiffRepresentation
                            appSFSymbol = getControlCenterIcon(appName: appTitle)
                        } else {
                            appTitle    = app.localizedName ?? "Unknown"
                            appIcon     = app.icon?.tiffRepresentation
                            appSFSymbol = nil
                        }
                        
                        let appIsObscured = isMenuBarItemObscured(child)
                        let appBundleId   = getMenuBarBundleIdentifier(child, bundleIdentifier: app.bundleIdentifier ?? "unknown")
                        
                        var menuBarApp = MenuBarApp(
                            id: UUID(),
                            bundleIdentifier: appBundleId,
                            name: appTitle,
                            processIdentifier: app.processIdentifier,
                            iconData: appIcon,
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
}

/// Extension: Manager to provide a 'click simulation' handler
extension MenuBarManager {
    func clickMenuBarApp(_ app: MenuBarApp) {
        guard let axElement = app.axElement else {
            NSLog("❌ No accessibility element stored for \(app.name)")
            return
        }
        
        // Try the press action first
        let pressResult = AXUIElementPerformAction(axElement, kAXPressAction as CFString)
        
        if pressResult == .success {
            NSLog("✅ Successfully clicked \(app.name)")
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
                NSLog("✅ Successfully performed action '\(action)' on \(app.name)")
                return
            }
        }
        
        NSLog("❌ Failed to interact with \(app.name) - no valid actions worked")
        
        // Debug: List available actions using the correct API
        var actionsRaw: CFArray?
        let actionsResult = AXUIElementCopyActionNames(axElement, &actionsRaw)
        
        if actionsResult == .success, let actions = actionsRaw as? [String] {
            NSLog("🔍 Available actions for \(app.name): \(actions)")
        }
    }
}
