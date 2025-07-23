//
//  AccessibilityRequest.swift
//  BarTap
//

import ApplicationServices
import Cocoa
import os

private let logger = Logger(subsystem: "io.github.0xZDH.BarTap", category: "AccessibilityRequest")

/// Helper function to check for accessibility access and, if not present, request it
func requestAccessibilityPermissionIfNeeded() -> Bool {
    let trusted = AXIsProcessTrusted()
    if !trusted {
        logger.warning("Please grant accessibility permissions via: System Preferences -> Security & Privacy -> Privacy -> Accessibility")
        
        let options: [String: AnyObject] = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true as CFBoolean
        ]
        
        // Request permissions
        let promptResult = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if !promptResult {
            logger.error("User may need to manually grant accessibility permissions")
            logger.notice("Instructions:\n   1. Open System Preferences\n   2. Go to Security & Privacy > Privacy > Accessibility\n   3. Click the lock to make changes\n   4. Add or enable this app: \(Bundle.main.bundleIdentifier ?? "BarTap")\n   5. Restart the app")
            
            return false
        }
    }
    
    return true
}

/// Helper function to force a dummy scan to add BarTap to the accessibility permissions
func forceAccessibilityDummyScan() {
    logger.warning("Accessibility not trusted. Trying to force registration...")
    
    // Try to access the system-wide element anyway to trigger listing
    // This call will trigger the system to *eventually* list your app if it's not trusted
    let dummy = AXUIElementCreateSystemWide()
    var ignored: AnyObject?
    let _ = AXUIElementCopyAttributeValue(dummy, kAXFocusedApplicationAttribute as CFString, &ignored)
}
