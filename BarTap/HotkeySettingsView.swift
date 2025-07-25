//
//  HotkeySettingsView.swift
//  BarTap
//

import SwiftUI
import Carbon

struct HotkeySettingsView: View {
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    
    @State private var newHotkey: Hotkey?
    @State private var activeHotkey: Hotkey?
    
    @State private var isRecording: Bool = false
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Hotkey Settings")
                .font(.title)
                .fontWeight(.bold)

            Text("Click below to record a new hotkey...")
                .font(.callout)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Open BarTap")
                    .font(.headline)
                
                Button(action: self.startRecording) {
                    Text(buttonText)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.semibold)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(isRecording ? Color.blue : Color(NSColor.controlBackgroundColor))
                        .foregroundColor(isRecording ? .white : .primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isRecording ? Color.blue : Color.gray.opacity(0.5), lineWidth: isRecording ? 2 : 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Show the save button only if a new, valid hotkey has been recorded.
            if let newHotkey = newHotkey, newHotkey != activeHotkey {
                Button(action: saveHotkey) {
                    Text("Save Hotkey")
                        .fontWeight(.semibold)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Text("Active Hotkey: \(formatHotkey(keys: activeHotkey?.keys ?? []))")
                .foregroundColor(.secondary)
                .padding(.top, 10)
        }
        .padding(40)
        .frame(width: 400)
        .onAppear(perform: loadHotkey)
    }
    
    // Computed property to determine the text for the main button.
    private var buttonText: String {
        if isRecording {
            return "Recording..."
        }
        
        if let newHotkey = newHotkey {
            return formatHotkey(keys: newHotkey.keys)
        }
        
        if let activeHotkey = activeHotkey {
            return formatHotkey(keys: activeHotkey.keys)
        }
        
        return "Click to set hotkey"
    }
    
    // MARK: - Hotkey Recording
    
    private func startRecording() {
        if isRecording { return }
        isRecording = true
        
        // Listen for local key down events to record the new hotkey.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyEvent(event)
            return nil
        }
    }
    
    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isRecording = false
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        stopRecording()
        
        // Ignore events that are just modifier key presses.
        guard !event.isARepeat, event.keyCode < 128 else { return }
        
        var keys: [String] = []
        var carbonModifiers: UInt32 = 0
        
        if event.modifierFlags.contains(.command) {
            keys.append("Command")
            carbonModifiers |= UInt32(cmdKey)
        }
        if event.modifierFlags.contains(.control) {
            keys.append("Control")
            carbonModifiers |= UInt32(controlKey)
        }
        if event.modifierFlags.contains(.option) {
            keys.append("Option")
            carbonModifiers |= UInt32(optionKey)
        }
        if event.modifierFlags.contains(.shift) {
            keys.append("Shift")
            carbonModifiers |= UInt32(shiftKey)
        }
        
        if let key = event.charactersIgnoringModifiers?.uppercased(), !key.isEmpty {
            keys.append(key)
        }
        
        // A valid hotkey must have at least one modifier and a main key.
        if keys.count > 1 {
            self.newHotkey = Hotkey(keys: keys, keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
        }
    }
    
    // MARK: - Saving and Loading
    
    /// Persist hotkey to UserDefaults
    private func saveHotkey() {
        guard let hotkeyToSave = newHotkey else { return }
        
        // Save to UserDefaults
        hotkeyManager.saveHotkey(hotkeyToSave)
        
        // Update the active hotkey and re-register
        self.activeHotkey = hotkeyToSave
        hotkeyManager.register(hotkey: self.activeHotkey)
    }
    
    /// Load hotkey from UserDefaults
    private func loadHotkey() {
        guard let savedHotkey = hotkeyManager.loadHotkey() else {
            return
        }
        
        self.activeHotkey = savedHotkey
        self.newHotkey = savedHotkey
    }
}

/// A helper function to format the key combination into a readable string with symbols.
func formatHotkey(keys: [String]) -> String {
    if keys.isEmpty { return "None" }
    
    let specialKeys: [String: String] = [
        "CAPSLOCK": "⇪",
        "COMMAND":  "⌘",
        "CONTROL":  "⌃",
        "OPTION":   "⌥",
        "SHIFT":    "⇧"
    ]
    
    return keys.map { key in
        specialKeys[key.uppercased()] ?? key.uppercased()
    }.joined(separator: " + ")
}
