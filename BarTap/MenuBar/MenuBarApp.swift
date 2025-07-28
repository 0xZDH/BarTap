//
//  MenuBarApp.swift
//  BarTap
//

import SwiftUI

/// Menu bar application data model
struct MenuBarApp: Identifiable, Codable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let iconPath: String?     // Path to cached icon
    let sfSymbolName: String? // Icon fallback
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
    init(id: UUID, name: String, bundleIdentifier: String, processIdentifier: pid_t, iconPath: String?, sfSymbolName: String?) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.iconPath = iconPath
        self.sfSymbolName = sfSymbolName
    }
    
    // Custom coding to handle the non-Codable AXUIElement
    enum CodingKeys: String, CodingKey {
        case id, name, bundleIdentifier, processIdentifier, iconPath, sfSymbolName
    }
}
