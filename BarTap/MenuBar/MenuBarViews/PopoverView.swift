//
//  PopoverView.swift
//  BarTap
//

import SwiftUI

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
