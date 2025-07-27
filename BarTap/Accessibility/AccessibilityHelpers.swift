//
//  AccessibilityHelpers.swift
//  BarTap
//

import SwiftUI

// MARK: - Accessibility Parsers

/// Get the bundle identifier of the child object, if applicable
func getMenuBarBundleIdentifier(_ axElement: AXUIElement, bundleIdentifier: String) -> String {
    let attributeName = "AXIdentifier" as CFString
    
    var valueRaw: AnyObject?
    let result = AXUIElementCopyAttributeValue(axElement, attributeName, &valueRaw)
    
    if result == .success, let value = valueRaw as? String, !value.isEmpty {
        return value
    }
    
    // Fallback to original app bundle ID
    return bundleIdentifier
}

/// Identify granular names for control center applications
func getMenuBarItemName(_ axElement: AXUIElement, appName: String) -> String {
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

/// Get the SF symbol of the Control Center app
func getControlCenterIcon(appName: String) -> String? {
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

/// Check if a menu bar icon is either hidden from the layout OR obscured by the
/// active app's menu
/// NOTE: This is only working for app menu obscurity, not the Mac laptop camera notch
func isMenuBarItemObscured(_ axElement: AXUIElement, appMenuBoundaryX: CGFloat?) -> Bool {
    // Get the frame of the icon itself
    guard let iconFrame = getElementFrame(axElement) else { return true }
    
    // Check if the icon is hidden from the layout (its frame is zero)
    if iconFrame.isNull || iconFrame.isEmpty {
        return true
    }
    
    // If we couldn't determine the boundary, assume the icon is visible
    guard let appMenuBoundaryX = appMenuBoundaryX else {
        return false
    }
    
    // An icon is obscured if its starting point (minX) is to the left of
    // the app menu's rightmost boundary
    if iconFrame.minX < appMenuBoundaryX {
        return true
    }
    
    // Default: Assume visible
    return false
}

// MARK: - Support Accessibility Functions

/// Gets the `CGRect` frame for any given AXUIElement
private func getElementFrame(_ axElement: AXUIElement) -> CGRect? {
    // Get position
    var positionValue: CFTypeRef?
    let posAttr = NSAccessibility.Attribute.position.rawValue as CFString
    guard AXUIElementCopyAttributeValue(axElement, posAttr, &positionValue) == .success,
          let posVal = positionValue else { return nil }
    var position = CGPoint.zero
    guard AXValueGetValue(posVal as! AXValue, .cgPoint, &position) else { return nil }
    
    // Get size
    var sizeValue: CFTypeRef?
    let sizeAttr = NSAccessibility.Attribute.size.rawValue as CFString
    guard AXUIElementCopyAttributeValue(axElement, sizeAttr, &sizeValue) == .success,
          let sizeVal = sizeValue else { return nil }
    var size = CGSize.zero
    guard AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else { return nil }
    
    return CGRect(origin: position, size: size)
}

private var cachedAppMenuBoundaryX: CGFloat?
private var boundaryXCacheTime: Date?
private let boundaryXCacheInterval: TimeInterval = 2.0 // Cache for 2 seconds

/// Attempt to first retrieve the app boundary from cache
func getCachedAppMenuBoundaryX() -> CGFloat? {
    let now = Date()
    if let cacheTime = boundaryXCacheTime,
       let cached = cachedAppMenuBoundaryX,
       now.timeIntervalSince(cacheTime) < boundaryXCacheInterval {
        return cached
    }
    
    let boundary = onMain { getActiveAppMenuBoundaryX() }
    cachedAppMenuBoundaryX = boundary
    boundaryXCacheTime = now
    return boundary
}

/// Find the rightmost coordinate (maxX) of the frontmost application's menu bar
private func getActiveAppMenuBoundaryX() -> CGFloat? {
    // Get the frontmost application's accessibility element
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return nil }
    let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
    
    // Find the menu bar elements within the application
    var menuBarValue: CFTypeRef?
    let menuBarAttr = NSAccessibility.Attribute.menuBar.rawValue as CFString
    
    guard AXUIElementCopyAttributeValue(appElement, menuBarAttr, &menuBarValue) == .success,
    let unwrappedValue = menuBarValue else {
        return nil
    }
    
    let menuBar = unwrappedValue as! AXUIElement

    // Get the children of the menu bar (e.g., "File", "Edit", "View").
    var childrenValue: CFTypeRef?
    let childrenAttr = NSAccessibility.Attribute.children.rawValue as CFString
    guard AXUIElementCopyAttributeValue(menuBar, childrenAttr, &childrenValue) == .success,
    let children = childrenValue as? [AXUIElement], let lastMenuItem = children.last else {
        return nil
    }
    
    // Get the frame of the *last* menu item
    guard let lastItemFrame = getElementFrame(lastMenuItem) else { return nil }
    
    // The true boundary is the rightmost edge of this last item
    return lastItemFrame.maxX
}
