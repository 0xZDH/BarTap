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
    
    /// Caches icon data and returns the file path
    /// - Parameters:
    ///   - iconData: The raw `Data` of the icon to be cached
    ///   - bundleIdentifier: The bundle identifier of the application, used for unique filenames
    /// - Returns: An optional `String` containing the path to the cached icon file
    func cacheIcon(iconData: Data, for bundleIdentifier: String) -> String? {
        guard let iconCacheDirectory = iconCacheDirectory else {
            NSLog("❌ Icon cache directory is not available.")
            return nil
        }
        
        // Sanitize the bundle identifier to create a valid filename
        let sanitizedFilename = bundleIdentifier.replacingOccurrences(of: "[^a-zA-Z0-9.-]", with: "_", options: .regularExpression)
        let fileURL = iconCacheDirectory.appendingPathComponent("\(sanitizedFilename).png")
        
        // Check if the file already exists, skip re-creation
        let fileExists = fileManager.fileExists(atPath: fileURL.path)
        if fileExists {
            return fileURL.path
        }
        
        // Write the app icon data to disk
        do {
            try iconData.write(to: fileURL)
            return fileURL.path
        } catch {
            NSLog("❌ Failed to write icon to cache for \(bundleIdentifier): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Loads an `NSImage` from a given file path
    /// - Parameter path: The file path of the image to load
    /// - Returns: An optional `NSImage` if loading is successful
    func getIcon(from path: String) -> NSImage? {
        return NSImage(contentsOfFile: path)
    }
} 
