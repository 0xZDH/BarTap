//
//  AppDelegate.swift
//  BarTap
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private let menuBarManager = MenuBarManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Mark application as accessory, do not show in dock
        NSApp.setActivationPolicy(.accessory)
        
        let accessibilityCheck = requestAccessibilityPermissionIfNeeded()
        if (!accessibilityCheck) {
            forceAccessibilityDummyScan()
        }
        
        // Create the menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            var image = NSImage(named: NSImage.Name("MenuBarIcon"))

            let imageSize = NSSize(width: 36, height: 36)
            image = image?.resize(withSize: imageSize) // Resize image

            // Ensures proper dark/light mode rendering
            image?.isTemplate = true

            button.image = image
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        
        // Create SwiftUI-based popover
        popover = NSPopover()
        popover.behavior = .transient // This should close when clicking outside the window
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                menuBarManager: menuBarManager,
                closePopover: { [weak self] in
                    self?.closePopover()
                }
            )
        )
        
        // On application load, perform initial app scan
        if menuBarManager.detectedApps.isEmpty {
            menuBarManager.refreshApps()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Ensure the event monitor is properly cleaned up on quit
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
    
    /// When clicking the menu bar icon, toggle the popover on and off
    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }
    
    /// Reveal the popover
    private func showPopover() {
        // Show the popover relative to the menu bar icon
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            // Add an event monitor to detect clicks outside of the popover
            // (backup for .transient behavior)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
                [weak self] event in
                if let strongSelf = self, strongSelf.popover.isShown {
                    strongSelf.closePopover()
                }
            }
        }
    }
    
    /// Close the popover
    private func closePopover() {
        popover.performClose(nil)
        
        // Remove the event monitor
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
