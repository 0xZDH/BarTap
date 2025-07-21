//
//  BarTapView.swift
//  BarTap
//

import SwiftUI

// MARK: - Popover View

struct PopoverView: View {
    @StateObject private var menuBarManager = MenuBarManager()
    let closePopover: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("BarTap")
                .font(.headline)
                
                Spacer()
                
                Button("Refresh") {
                    menuBarManager.refreshApps()
                }
                .disabled(menuBarManager.isScanning)
            }
            
            Divider()
            
            // Application list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(menuBarManager.detectedApps) { app in
                        MenuBarAppRow(app: app, manager: menuBarManager)
                    }
                }
                .padding(.leading, 4) // Add leading padding to the entire list
                .padding(.trailing, 8) // Add trailing padding to the entire list
            }
            .frame(maxHeight: 400) // Limit the scroll window size
            
            // Footer
            HStack {
                Text("\(menuBarManager.detectedApps.count) apps")
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Close") {
                    closePopover()
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            // Initialize app loading on popover display
            menuBarManager.refreshApps()
        }
    }
}

// MARK: - Application Row View

struct MenuBarAppRow: View {
    let app: MenuBarApp
    let manager: MenuBarManager
    @State private var isHovered: Bool = false
    
    var body: some View {
        // Define the entire row as a 'button'
        Button(action: {
            manager.clickMenuBarApp(app)
        }) {
            HStack {
                // App icon
                if let sfSymbolName = app.sfSymbolName {
                    // Support custom imagesets (e.g. Bluetooth)
                    if sfSymbolName.hasPrefix("custom:") {
                        let imagesetName = String(sfSymbolName.dropFirst(7)) // Remove "custom:" prefix
                        Image(imagesetName)
                            .resizable()
                            .renderingMode(.template) // Behave like SF Symbols in light/dark mode
                            .foregroundColor(.primary)
                            .frame(width: 16, height: 16)
                    } else {
                        // Render SF Symbol with proper template behavior
                        Image(systemName: sfSymbolName)
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(.primary) // Support light/dark mode
                            .frame(width: 16, height: 16)
                    }
                } else if let iconData = app.iconData,
                          let nsImage = NSImage(data: iconData) {
                    // Render regular app icon
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 16, height: 16)
                } else {
                    // Fallback to generic SF app icon
                    Image(systemName: "app")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.primary)
                        .frame(width: 16, height: 16)
                }
                
                // App name
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Text(app.bundleIdentifier)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(app.isRunning ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                
                // Actions (only show on hover)
                if isHovered {
                    HStack(spacing: 4) {
                        // Click button
                        //Button(action: {
                        //    manager.clickMenuBarApp(app)
                        //}) {
                        //    Image(systemName: "hand.tap")
                        //        .font(.system(size: 10))
                        //}
                        //.buttonStyle(.plain)
                        //.help("Click menu bar item")
                        
                        // Quit/Launch button
                        Button(action: {
                            if app.isRunning {
                                manager.quitApp(app)
                            } else {
                                manager.launchApp(app)
                            }
                        }) {
                            Image(systemName: app.isRunning ? "xmark.circle" : "play.circle")
                                .font(.system(size: 14))
                                .foregroundColor(app.isRunning ? .red : .green)
                        }
                        .buttonStyle(.plain)
                        .help(app.isRunning ? "Quit app" : "Launch app")
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .padding(.trailing, 12)
        }
        .buttonStyle(.plain)
        .background(
            // Highlight the app row when 'hovering'
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.10), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.10)) {
                isHovered = hovering
            }
        }
        // Right-click context menu
        .contextMenu {
            Button("Click Menu Bar Item") {
                manager.clickMenuBarApp(app)
            }
            
            Divider()
            
            Button("Open Application") {
                manager.launchApp(app)
            }
            
            if app.isRunning {
                Button("Quit Application") {
                    manager.quitApp(app)
                }
            }
        }
        .help("Click to trigger \(app.name) menu bar item")
    }
}
