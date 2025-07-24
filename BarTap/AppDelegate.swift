//
//  AppDelegate.swift
//  BarTap
//

import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    
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
        
        // Register the global hotkey once the popover view has been created
        registerHotkey()
        
        // On application load, perform initial app scan
        if menuBarManager.detectedApps.isEmpty {
            menuBarManager.refreshApps()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Ensure the event monitors are properly cleaned up on quit
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        
        if let hotKeyRef = self.hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
    
    /// Toggle the popover view on and off
    @objc func togglePopover(_ sender: AnyObject?) {
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
            // Only enable the event monitor when the popover is actively showing
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
    
    /// Register the global hotkey with the Carbon Event Manager
    private func registerHotkey() {
        let hotKeyId = EventHotKeyID(signature: "btap".fourCharCode, id: 1)
        
        // Define the hotkey combination
        // ctrl + shift + \
        let keyCode = UInt32(kVK_ANSI_Backslash)
        let modifiers = UInt32(controlKey | shiftKey)
        
        // Register the hotkey
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        // Pass a pointer to the current AppDelegate to the event handler
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        var eventHandlerRef: EventHandlerRef? = nil
        InstallEventHandler(GetEventDispatcherTarget(), hotKeyHandler, 1, &eventType, selfPtr, &eventHandlerRef)
        
        // Register the hotkey and save the reference to later unregister it
        RegisterEventHotKey(keyCode, modifiers, hotKeyId, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

/// Handle hotkey events
private func hotKeyHandler(eventHandlerCall: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    // Extract the AppDelegate instance that we passed in as a self pointer
    guard let userData = userData else { return noErr }
    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    
    appDelegate.togglePopover(nil)
    
    return noErr
}

/// Convert a four-character string into the `OSType` format required by Carbon
extension String {
    var fourCharCode: FourCharCode {
        return self.utf16.reduce(0, {$0 << 8 + FourCharCode($1)})
    }
}
