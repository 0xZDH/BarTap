//
//  ApplicationObserver.swift
//  BarTap
//

import SwiftUI
import os

///  Monitor macOS apps
class ApplicationObserver: ObservableObject {
    @Published private(set) var knownPIDs = Set<pid_t>()
    
    @ObservedObject private var menuBarManager: MenuBarManager
    private var cancellable: NSKeyValueObservation?
    private var pidWatchers: [pid_t: DispatchSourceProcess] = [:]
    
    private let logger = Logger(subsystem: "io.github.0xZDH.BarTap", category: "BackgroundObserver")
    
    init(manager: MenuBarManager) {
        self.menuBarManager = manager
        
        seedKnownApps()
        
        cancellable = NSWorkspace.shared.observe(\.runningApplications, options: [.new, .old]) {
            [weak self] _, change in
            
            guard let newApps = change.newValue else { return }
            
            let newAppsSet = Set(newApps.map(\.processIdentifier)) // Get PIDs only
            newAppsSet.forEach { pid in self?.startWatching(pid) }
        }
    }
    
    /// Initial seeding of known apps
    private func seedKnownApps() {
        // Get a baseline of 'all known' PIDs
        knownPIDs = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        
        // Start monitoring known menu bar applications only
        // if we have detected apps (avoid race conditions with initial scan)
        // Avoid 'monitoring' all running applications at launch since we know
        // they do not all have menu bar applications
        if !menuBarManager.detectedApps.isEmpty {
            menuBarManager.detectedApps.map(\.processIdentifier).forEach { [weak self] pid in
                self?.startWatching(pid, seed: true)
            }
        }
    }
    
    /// Start monitoring a new accessory app
    private func startWatching(_ pid: pid_t, seed: Bool = false) {
        // When seeding, skip 'handling' the known apps to the BarTap manager
        if !seed {
            guard let app = NSRunningApplication(processIdentifier: pid) else { return }
            
            knownPIDs.insert(pid)
            
            Task.detached(priority: .background) { [weak self] in
                // Attempt to wait for the app to finish launching, but even if
                // .isFinishedLaunching never returns true - try to process the
                // app anyway
                await app.waitForFinishedLaunching(timeout: 5.0)
                
                // Force wait for an application to finish its launch sequence
                //try await Task.sleep(nanoseconds: 15_000_000_000) // wait for 15 seconds
                
                await self?.menuBarManager.addApp(app)
            }
        }
        
        // Create a cheap kernel watcher for the specified pid
        let src = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        
        src.setEventHandler { [weak self] in
            self?.stopWatching(pid)
        }
        
        pidWatchers[pid] = src // Track watchers for later cleanup
        src.resume()
    }
    
    /// Remove stopped accessory app from monitoring
    private func stopWatching(_ pid: pid_t)  {
        // Make handler idempotent
        guard knownPIDs.remove(pid) != nil else { return }
        
        menuBarManager.removeApp(forPID: pid) // Stop tracking the app
        pidWatchers.removeValue(forKey: pid)?.cancel() // Cancel the watcher
    }
}
