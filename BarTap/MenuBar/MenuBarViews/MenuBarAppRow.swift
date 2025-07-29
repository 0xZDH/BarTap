//
//  MenuBarAppRow.swift
//  BarTap
//

import SwiftUI

struct MenuBarAppRow: View {
    let app: MenuBarApp
    let manager: MenuBarManager
    let searchText: String

    let closePopover: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        // Define the entire row as a 'button'
        Button(action: {
            manager.clickMenuBarApp(app)
            closePopover() // Attempt to force close
        }) {
            HStack {
                // App icon
                appIcon
                
                // App name and identifier with search highlighting
                VStack(alignment: .leading, spacing: 2) {
                    HighlightedText(
                        text: app.name,
                        searchText: searchText,
                        font: .system(size: 12, weight: .medium),
                        foregroundColor: .primary
                    )
                    
                    HighlightedText(
                        text: app.bundleIdentifier,
                        searchText: searchText,
                        font: .system(size: 10),
                        foregroundColor: .secondary
                    )
                }
                
                Spacer()
                
                // Status indicator
                HStack(spacing: 4) {
                    // Running status
                    Circle()
                        .fill(app.isRunning ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    
                    // Visibility status for hidden items
                    if app.isObscured {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                            .help("Hidden/Obscured")
                    }
                }
                
                // Actions
                if isHovered {
                    actionButtons
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .padding(.trailing, 12)
        }
        .buttonStyle(.plain)
        .background(rowBackground)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.10), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            contextMenuItems
        }
        .help("Click to trigger \(app.name) menu bar item")
    }
    
    // MARK: - Subviews
    
    /// Dynamic app icon generation
    @ViewBuilder
    private var appIcon: some View {
        if let sfSymbolName = app.sfSymbolName {
            // Use custom images for things like 'Bluetooth'
            if sfSymbolName.hasPrefix("custom:") {
                let imagesetName = String(sfSymbolName.dropFirst(7))
                Image(imagesetName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.primary)
                    .frame(width: 16, height: 16)
            } else {
                // For scenarios like Control Center, use an
                // SF symbol instead of the parent icon
                Image(systemName: sfSymbolName)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.primary)
                    .frame(width: 16, height: 16)
            }
        // Use the application icon from cached storage
        } else if let iconPath = app.iconPath,
                  let nsImage = IconCacheManager.state.getIcon(from: iconPath) {
            Image(nsImage: nsImage)
                .resizable()
                .frame(width: 16, height: 16)
        } else {
            // Fallback icon if none available
            Image(systemName: "app")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.primary)
                .frame(width: 16, height: 16)
        }
    }
    
    /// Action buttons for focused applications
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 4) {
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
    
    /// Row background of hovered row
    @ViewBuilder
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
    }
    
    /// Right-click context menu
    @ViewBuilder
    private var contextMenuItems: some View {
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
}
