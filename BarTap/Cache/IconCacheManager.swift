//
//  IconCacheManager.swift
//  BarTap
//

import SwiftUI
import os

class IconCacheManager {
    static let state = IconCacheManager()
    
    // Keep recently-used icons in memory to avoid repeated
    // `NSImage(contentsOfFile:)` disk hits
    private let memoryCache = NSCache<NSString, NSImage>()
    
    private let fileManager = FileManager.default
    private var iconCacheDirectory: URL?
    private let logger = Logger(subsystem: "io.github.0xZDH.BarTap", category: "IconCacheManager")
    
    private init() {
        setupCacheDirectory()
        
        memoryCache.countLimit = 256 // Keep memory bounded
        memoryCache.totalCostLimit = 32 * 32 * 4 * 256   // ≈1 MB
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
    
    /// Check if an app icon has already been cached and determine if it has become stale
    func getCachedIcon(for bundleIdentifier: String, appURL: URL?) -> String? {
        guard let cacheDir = iconCacheDirectory else { return nil }
        
        // Sanitize the bundle identifier to create a valid filename
        let sanitizedId = bundleIdentifier.replacingOccurrences(of: "[^a-zA-Z0-9-.]", with: "_", options: .regularExpression)
        let iconURL = cacheDir.appendingPathComponent("\(sanitizedId).png")
        
        if fileManager.fileExists(atPath: iconURL.path) {
            // If the app bundle URL isn't available, we skip the staleness check
            // and assume the cache is good
            guard let appURL = appURL,
                  let appModDate  = getModificationDate(for: appURL),
                  let iconModDate = getModificationDate(for: iconURL) else {
                return iconURL.path
            }
            
            if appModDate <= iconModDate {
                return iconURL.path
            }
        }
        
        // If the cache file doesn't exist or is stale, return nil
        return nil
    }
    
    /// Caches an application icon and returns the file path
    /// Instead of caching the full TIFF representation, we first resize the app icon
    /// as an NSImage and then convert it to a PNG and save the image
    func cacheIcon(icon: NSImage, for bundleIdentifier: String, from appBundleURL: URL?) -> String? {
        guard let cacheDir = iconCacheDirectory else { return nil }
        
        // Sanitize the bundle identifier to create a valid filename
        let sanitizedId = bundleIdentifier.replacingOccurrences(of: "[^a-zA-Z0-9-.]", with: "_", options: .regularExpression)
        let iconURL = cacheDir.appendingPathComponent("\(sanitizedId).png")
        
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
    
    /// Retrieve a cached icon from the filesystem
    func getIcon(from path: String) -> NSImage? {
        // Attempt to retrieve the image from in-memory cache before
        // requesting from on-disk
        if let cachedImage = memoryCache.object(forKey: path as NSString) {
            return cachedImage
        }
        
        // Load the image from disk
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        
        // Save the image to in-memory cache once its been loaded from
        // disk
        memoryCache.setObject(image, forKey: path as NSString, cost: 32*32*4)
        return image
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
