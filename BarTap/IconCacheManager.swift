//
//  IconCacheManager.swift
//  BarTap
//

import SwiftUI
import os

class IconCacheManager {
    static let state = IconCacheManager() // Shared state
    
    private let fileManager = FileManager.default
    private var iconCacheDirectory: URL?
    private let logger = Logger(subsystem: "io.github.0xZDH.BarTap", category: "IconCacheManager")
    
    private init() {
        setupCacheDirectory()
    }
    
    /// Set up the cache directory in the Application Support directory
    private func setupCacheDirectory() {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Failed to find the Application Support directory.")
            return
        }
        
        let appName = "BarTap"
        let baseDirectory = appSupportURL.appendingPathComponent(appName)
        let iconDirectory = baseDirectory.appendingPathComponent("icons")
        
        do {
            try fileManager.createDirectory(at: iconDirectory, withIntermediateDirectories: true, attributes: nil)
            self.iconCacheDirectory = iconDirectory
        } catch {
            logger.error("Failed to create the cache directory: \(error.localizedDescription)")
        }
    }
    
    /// Caches an application icon and returns the file path
    /// Instead of caching the full TIFF representation, we first resize the app icon
    /// as an NSImage and then convert it to a PNG and save the image
    func cacheIcon(icon: NSImage, for bundleIdentifier: String, from appBundleURL: URL?) -> String? {
        guard let cacheDir = iconCacheDirectory else { return nil }
        
        // Sanitize the bundle identifier to create a valid filename
        let sanitizedId = bundleIdentifier.replacingOccurrences(of: "[^a-zA-Z0-9-.]", with: "_", options: .regularExpression)
        let iconURL = cacheDir.appendingPathComponent("\(sanitizedId).png")
        
        // If a cached icon exists, check if it's stale by comparing modification dates
        if fileManager.fileExists(atPath: iconURL.path) {
            // Compare the apps modification date to the cached icon
            // creation date
            guard let appBundleURL = appBundleURL,
                  let appModDate   = getModificationDate(for: appBundleURL),
                  let iconModDate  = getModificationDate(for: iconURL) else {
                return iconURL.path
            }
            
            // If the icon was created/modified more recently than the application,
            // assume it's fresh and return the file path
            // Otherwise, continue and refresh the app icon cache
            if appModDate <= iconModDate {
                return iconURL.path
            }
        }
        
        // Resize the NSImage to 32x32 for memory efficiency since app icons are displayed
        // at 16x16
        guard let resizedIcon = icon.resize(withSize: NSSize(width: 32, height: 32)) else { return nil }
        
        // Convert the resized image to PNG data
        guard let pngData = resizedIcon.PNGRepresentation else {
            logger.error("Failed to get PNG representation for \(bundleIdentifier)")
            return nil
        }
        
        do {
            try pngData.write(to: iconURL, options: .atomic)
            return iconURL.path
        } catch {
            logger.error("Failed to write icon to cache for \(bundleIdentifier): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Retrieves a cached icon from the filesystem
    func getIcon(from path: String) -> NSImage? {
        return NSImage(contentsOfFile: path)
    }
    
    /// Get the last modification date for a file at a given URL
    private func getModificationDate(for url: URL) -> Date? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }
}
