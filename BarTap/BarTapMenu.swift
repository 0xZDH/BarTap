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
                        
                        let appBundleId = getMenuBarBundleIdentifier(child, bundleIdentifier: app.bundleIdentifier ?? "unknown")
                        
                        var menuBarApp = MenuBarApp(
                            id: UUID(),
                            bundleIdentifier: appBundleId,
                            name: appTitle,
                            processIdentifier: app.processIdentifier,
                            iconData: appIcon,
                            sfSymbolName: appSFSymbol
                        )
                        
                        // Store the accessibility element for later interaction
                        menuBarApp.axElement = child
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
        
        // Try the press action first (most common)
        let pressResult = AXUIElementPerformAction(axElement, kAXPressAction as CFString)
        
        if pressResult == .success {
            NSLog("✅ Successfully clicked \(app.name)")
            return
        }
        
        // If press doesn't work, try other common actions
        let actionsToTry = [
            kAXPressAction as CFString,
            "AXMenuOpen" as CFString,
            "AXLeftClick" as CFString,
            "AXClick" as CFString
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

/// Helper function: Get the bundle identifier of the child object, if applicable
private func getMenuBarBundleIdentifier(_ axElement: AXUIElement, bundleIdentifier: String) -> String {
    let attributeName = "AXIdentifier" as CFString
    
    var valueRaw: AnyObject?
    let result = AXUIElementCopyAttributeValue(axElement, attributeName, &valueRaw)
    
    if result == .success, let value = valueRaw as? String, !value.isEmpty {
        return value
    }
    
    // Fallback to original app bundle ID
    return bundleIdentifier
}

/// Helper function: Identify granular names for control center applications
private func getMenuBarItemName(_ axElement: AXUIElement, appName: String) -> String {
    // Try multiple accessibility attributes to get a more specific name
    let attributesToTry = [
        kAXTitleAttribute           as CFString,
        kAXDescriptionAttribute     as CFString,
        kAXHelpAttribute            as CFString,
        kAXRoleDescriptionAttribute as CFString,
        kAXValueAttribute           as CFString,
        "AXIdentifier"              as CFString
    ]
    
    for attribute in attributesToTry {
        var valueRaw: AnyObject?
        let result = AXUIElementCopyAttributeValue(axElement, attribute, &valueRaw)
        
        if result == .success, let value = valueRaw as? String, !value.isEmpty {
            // Handle edge-case scenarios like "Wi-Fi, connected, 3 bars"
            let returnValue = value.split(separator: ",")[0]
            return String(returnValue)
        }
    }
    
    // Fallback to original app name
    return appName
}

/// Helper function: Get the SF symbol of the Control Center app
private func getControlCenterIcon(appName: String) -> String? {
    // Map Control Center app names to SF Symbol names
    let iconMapping: [String: String] = [
        // Connectivity
        "WiFi":  "wifi",
        "Wi-Fi": "wifi",
        "Wi‑Fi": "wifi", // Varying 'dash'
        "Bluetooth": "custom:BluetoothIcon",
        "AirDrop": "airplayaudio",
        "Personal Hotspot": "personalhotspot",
        "Cellular Data": "antenna.radiowaves.left.and.right",
        "VPN": "lock.shield",
        
        // Display & Sound
        "Display": "display",
        "Brightness": "sun.max",
        "Volume": "speaker.wave.3",
        "Sound": "speaker.wave.2",
        "Dark Mode": "moon",
        "True Tone": "circle.lefthalf.filled",
        "Night Shift": "moon.circle",
        
        // Power & Battery
        "Battery": "battery.100",
        "Low Power Mode": "battery.25",
        
        // Time & Clock
        "Clock": "clock",
        "Timer": "timer",
        "Stopwatch": "stopwatch",
        "Alarm": "alarm",
        
        // Focus & Do Not Disturb
        "Do Not Disturb": "moon.circle.fill",
        "Focus": "moon.circle",
        
        // Media Controls
        "Music": "music.note",
        "Now Playing": "music.note",
        "AirPlay": "airplayvideo",
        "Screen Mirroring": "rectangle.on.rectangle",
        
        // Accessibility
        "Accessibility Shortcuts": "accessibility",
        "Magnifier": "magnifyingglass",
        "Voice Control": "mic",
        "Switch Control": "switch.2",
        "AssistiveTouch": "hand.point.up.left",
        "Hearing": "ear",
        "Zoom": "plus.magnifyingglass",
        
        // System Controls
        //"Control Center": "control", // Ignore: Use Control Center app icon
        "Screen Recording": "record.circle",
        "Camera": "camera",
        "Flashlight": "flashlight.on.fill",
        "Calculator": "function",
        "Notes": "note.text",
        "Airplane Mode": "airplane",
        
        // Stage Manager & Window Management
        "Stage Manager": "rectangle.3.group",
        "Mission Control": "rectangle.grid.3x2",
        
        // Shortcuts & Apps
        "Shortcuts": "app.connected.to.app.below.fill",
        "Siri": "mic.circle",
        
        // Wallet & Payment
        "Apple Pay": "creditcard",
        "Wallet": "wallet.pass",
        
        // Home & Remote Controls
        "Home": "house",
        "Apple TV Remote": "appletv",
        "Remote": "tv",
        
        // Text & Input
        "Text Size": "textformat.size",
        "Keyboard Brightness": "keyboard",
        
        // Network & Internet
        "Hotspot": "wifi.router",
        "Internet Sharing": "wifi.square",
        
        // Location & Privacy
        "Location": "location",
        "Privacy": "hand.raised",
        
        // Storage & Files
        "Storage": "internaldrive",
        "Files": "folder"
    ]
    
    // Return the SF Symbol name or fallback to a generic control icon
    for (key, value) in iconMapping {
        // Check if a given key exists in the app name
        if appName.lowercased().contains(key.lowercased()) {
            return value
        }
    }
    
    // Fallback: Return an invalid SF icon to fallback to the app icon
    return nil
}
