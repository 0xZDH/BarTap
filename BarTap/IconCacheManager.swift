//
//  IconCacheManager.swift
//  BarTap
//

import SwiftUI

class IconCacheManager {
    static let state = IconCacheManager() // Shared state
    
    private let fileManager = FileManager.default
    private var iconCacheDirectory: URL?
    
    private init() {
        setupCacheDirectory()
    }
    
    /// Sets up the cache directory `~/.bartap/icons`
    private func setupCacheDirectory() {
        guard let homeDirectory = fileManager.homeDirectoryForCurrentUser as URL? else {
            NSLog("❌ Failed to find user home directory.")
            return
        }
        
        let baseCacheDirectory = homeDirectory.appendingPathComponent(".bartap")
        let iconDirectory = baseCacheDirectory.appendingPathComponent("icons")
        
        do {
            try fileManager.createDirectory(at: iconDirectory, withIntermediateDirectories: true, attributes: nil)
            self.iconCacheDirectory = iconDirectory
        } catch {
            NSLog("❌ Failed to create cache directory: \(error.localizedDescription)")
        }
    }
    
    /// Caches an application icon and returns the file path
    /// Instead of caching the full TIFF representation, we first resize the app icon
    /// as an NSImage and then convert it to a PNG and save the image
    func cacheIcon(icon: NSImage, for bundleIdentifier: String) -> String? {
        guard let cacheDir = iconCacheDirectory else { return nil }
        
        // Sanitize the bundle identifier to create a valid filename
        let sanitizedId = bundleIdentifier.replacingOccurrences(of: "[^a-zA-Z0-9-.]", with: "_", options: .regularExpression)
        let iconURL = cacheDir.appendingPathComponent("\(sanitizedId).png")
        
        if fileManager.fileExists(atPath: iconURL.path) {
            return iconURL.path
        }
        
        // Resize the NSImage to 32x32 for memory efficiency since app icons are displayed
        // at 16x16
        guard let resizedIcon = icon.resize(withSize: NSSize(width: 32, height: 32)) else { return nil }
        
        // Convert the resized image to PNG data
        guard let pngData = resizedIcon.PNGRepresentation else {
            NSLog("❌ Failed to get PNG representation for \(bundleIdentifier)")
            return nil
        }
        
        do {
            try pngData.write(to: iconURL, options: .atomic)
            return iconURL.path
        } catch {
            NSLog("❌ Failed to write icon to cache for \(bundleIdentifier): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Retrieves a cached icon from the filesystem
    func getIcon(from path: String) -> NSImage? {
        return NSImage(contentsOfFile: path)
    }
} 
