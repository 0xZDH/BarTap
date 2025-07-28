//
//  AppDelegate.swift
//  BarTap
//

import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    // Views
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow!
    
    // Events
    private var eventMonitor: Any?
    
    // Managers
    private let hotkeyManager = GlobalHotkeyManager()
    private let menuBarManager = MenuBarManager()
    private var applicationObserver: ApplicationObserver?
    
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
        
        // Create the SwiftUI-based popover
        popover = NSPopover()
        popover.behavior = .transient // This should close when clicking outside the window
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                // Managers
                menuBarManager: menuBarManager,
                
                // Event closures
                closePopover: { [weak self] in
                    self?.closePopover()
                },
                openSettings: { [weak self] in
                    self?.openSettings()
                }
            )
        )
        
        // Register the hotkey event closure
        hotkeyManager.hotkeyEvent = { [weak self] in
            self?.togglePopover(nil)
        }
        hotkeyManager.setup() // Initialize the hotkey event handler
        
        // Register the global hotkey once the popover view has been created
        // and the event handler is established
        if let savedHotkey = hotkeyManager.loadHotkey() {
            // Load from UserDefaults
            hotkeyManager.register(hotkey: savedHotkey)
        } else {
            // Default hotkey: ctrl + shift + |
            let defaultHotkey = Hotkey(
                keys: ["|"],
                keyCode: UInt32(124), // vertical bar (|)
                modifiers: UInt32(controlKey | shiftKey)
            )
            hotkeyManager.saveHotkey(defaultHotkey) // Save default on first run
            hotkeyManager.register(hotkey: defaultHotkey)
        }
        
        // On application load, perform initial app scan
        if menuBarManager.detectedApps.isEmpty {
            menuBarManager.refreshApps()
        }
        
        // Initialize background overserver
        applicationObserver = ApplicationObserver(manager: menuBarManager)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Ensure the event monitors are properly cleaned up on quit
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
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
            if eventMonitor == nil {
                eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
                    [weak self] event in
                    if let strongSelf = self, strongSelf.popover.isShown {
                        strongSelf.closePopover()
                    }
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
    
    /// Open the hotkey settings window, build if nil
    func openSettings() {
        if settingsWindow == nil {
            let settingsView = HotkeySettingsView(hotkeyManager: hotkeyManager)
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.center()
            settingsWindow?.setFrameAutosaveName("HotkeySettings")
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
