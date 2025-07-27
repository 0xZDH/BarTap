//
//  BarTapView.swift
//  BarTap
//

import SwiftUI

// MARK: - Popover View

struct PopoverView: View {
    @ObservedObject var menuBarManager: MenuBarManager
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    let closePopover: () -> Void
    let openSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("BarTap")
                    .font(.headline)
                
                Button(action: {
                    openSettings()
                    closePopover()
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(.primary)
                        .frame(width: 12, height: 12)
                }
                .help("Hotkey settings")
                
                Spacer()
                
                Button("Refresh") {
                    menuBarManager.refreshApps()
                }
                .disabled(menuBarManager.isScanning)
            }
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isSearchFocused)
                
                // When there is a 'search', add a way to clear the search
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            Divider()
            
            // Application list
            ScrollView {
                // Display a message to the user if the 'search' failed to
                // filter any applications
                if filteredApps.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        
                        Text("No apps found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try a different search term")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Clear Search") {
                            searchText = ""
                        }
                        .buttonStyle(.link)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredApps) { app in
                            MenuBarAppRow(app: app, manager: menuBarManager, searchText: searchText, closePopover: closePopover)
                        }
                    }
                    .padding(.leading, 4)
                    .padding(.trailing, 8)
                }
            }
            .frame(maxHeight: 400)
            
            // Footer
            HStack {
                Text(footerText)
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
    }
    
    // MARK: - Dynamic Properties
    
    /// Filter apps based on search text
    private var filteredApps: [MenuBarApp] {
        if searchText.isEmpty {
            return menuBarManager.detectedApps
        }
        
        return menuBarManager.detectedApps.filter { app in
            // Search in app name
            app.name.localizedCaseInsensitiveContains(searchText) ||
            // Search in bundle identifier
            app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    /// Dynamic footer text based on search state
    private var footerText: String {
        var lastScanned: String
        if menuBarManager.isScanning {
            lastScanned = "🔍 Scanning..."
        } else {
            lastScanned = menuBarManager.lastScannedTimestamp
        }
        
        if searchText.isEmpty {
            return "\(menuBarManager.detectedApps.count) apps | \(lastScanned)"
        } else {
            let filteredCount = filteredApps.count
            let totalCount = menuBarManager.detectedApps.count
            
            return "\(filteredCount) of \(totalCount) apps | \(lastScanned)"
        }
    }
}

// MARK: - Application Row View

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

// MARK: - Text Highlighting

struct HighlightedText: View {
    let text: String
    let searchText: String
    let font: Font
    let foregroundColor: Color
    
    var body: some View {
        if searchText.isEmpty {
            Text(text)
                .font(font)
                .foregroundColor(foregroundColor)
        } else {
            Text(highlightedAttributedString)
                .font(font)
        }
    }
    
    private var highlightedAttributedString: AttributedString {
        var attributedString = AttributedString(text)
        
        // Find all ranges of the search text (case-insensitive)
        let ranges = text.ranges(of: searchText, options: .caseInsensitive)
        
        for range in ranges.reversed() { // Reverse to maintain correct indices
            let startIndex = text.distance(from: text.startIndex, to: range.lowerBound)
            let endIndex = text.distance(from: text.startIndex, to: range.upperBound)
            
            let attributedRange = Range(
                NSRange(location: startIndex, length: endIndex - startIndex),
                in: attributedString
            )
            
            if let attributedRange = attributedRange {
                attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                attributedString[attributedRange].foregroundColor = foregroundColor
            }
        }
        
        // Set default color for non-highlighted text
        attributedString.foregroundColor = foregroundColor
        
        return attributedString
    }
}

/// String extension of range()
extension String {
    func ranges(of searchString: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchRange = startIndex..<endIndex
        
        while let range = range(of: searchString, options: options, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<endIndex
        }
        
        return ranges
    }
}
