//
//  HotkeyManager.swift
//  BarTap
//

import SwiftUI
import Carbon
import os

/// A struct to hold all necessary information about a hotkey
/// Codable conformance allows it to be easily saved to UserDefaults
struct Hotkey: Codable, Equatable {
    let keys: [String]
    let keyCode: UInt32
    let modifiers: UInt32
    
    // We need a custom Equatable check because NSEvent.ModifierFlags isn't directly Codable.
    static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        return lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }
}

class GlobalHotkeyManager: ObservableObject {
    private var hotkey: Hotkey?
    private var hotKeyRef: EventHotKeyRef?
    
    private let userDefaultsKey = "appHotkey"
    private let hotKeyId = EventHotKeyID(signature: "btap".fourCharCode, id: 1)
    
    private let logger = Logger(subsystem: "io.github.0xZDH.BarTap", category: "GlobalHotkeyManager")
    
    // Hotkey event closure
    var hotkeyEvent: (() -> Void)?
    
    /// Initialize the global event handler
    func setup() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        // When hotkey is pressed, call eventHandler() -> hotkeyEvent()
        let status = InstallEventHandler(GetApplicationEventTarget(), eventHandler, 1, &eventType, selfPtr, nil)
        if status != noErr {
            logger.error("InstallEventHandler failed with status \(status)")
        }
    }
    
    deinit {
        unregister()
    }
    
    // MARK: - Registration
    
    /// Register a hotkey event
    func register(hotkey: Hotkey?) {
        guard let hotkey = hotkey else { return }
        
        unregister() // Unregister existing hotkey event
        
        // Registration
        let status = RegisterEventHotKey(hotkey.keyCode, hotkey.modifiers, hotKeyId, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status == noErr {
            self.hotkey = hotkey
        } else {
            logger.error("RegisterEventHotKey failed with status \(status)")
        }
    }
    
    /// Unregister a hotkey event
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status != noErr {
                logger.warning("UnregisterEventHotKey returned status \(status)")
            }
            
            self.hotKeyRef = nil
        }
    }
    
    // MARK: - Save and Load
    
    /// Persist hotkey to UserDefaults
    func saveHotkey(_ hotkey: Hotkey?) {
        guard let hotkeyToSave = hotkey else { return }
        
        // Persist to UserDefaults
        if let data = try? JSONEncoder().encode(hotkeyToSave) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    /// Load hotkey from UserDefaults
    func loadHotkey() -> Hotkey? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let savedHotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return nil
        }
        
        return savedHotkey
    }
}

// MARK: - Event Handler

private func eventHandler(eventHandlerCall: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else {
        return noErr
    }
    
    // Convert the raw pointer back to a GlobalHotkeyManager instance
    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.hotkeyEvent?()
    
    return noErr
}
