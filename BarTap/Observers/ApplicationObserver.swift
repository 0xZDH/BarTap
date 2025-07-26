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
        
        // Seed existing apps on initialization
        seedKnownApps()
        
        // Only observe deltas from now on
        cancellable = NSWorkspace.shared.observe(\.runningApplications, options: [.new, .old]) {
            [weak self] _, change in
            self?.handleWorkspaceDelta(change)
        }
    }
    
    /// Get a list of current running accessory applications
    private func currentApps() -> Set<pid_t> {
        Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
    }
    
    /// Initial seeding of accessory apps
    private func seedKnownApps() {
        // Get initial baseline of 'all' PIDs
        knownPIDs = currentApps()
        
        menuBarManager.detectedApps.map(\.processIdentifier).forEach {
            pid in startWatching(pid, seed: true)
        }
    }
    
    /// Running application delta to identify new/removed applications
    private func handleWorkspaceDelta(_ change: NSKeyValueObservedChange<[NSRunningApplication]>) {
        // Get a snapshot of all accessory apps
        let current = currentApps()
        
        // Diff the snapshot with observed accessory apps
        let launched = current.subtracting(knownPIDs)
        let gone     = knownPIDs.subtracting(current)
        
        // Propagate the changes
        launched.forEach { pid in startWatching(pid) }
        gone.forEach     { pid in stopWatching(pid)  }
    }
    
    /// Start monitoring a new accessory app
    private func startWatching(_ pid: pid_t, seed: Bool = false) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        
        // When seeding, ignore 'adding' the apps to the BarTap manager
        // as this is handled by an initial full scan
        if !seed {
            knownPIDs.insert(pid)
            
            Task.detached(priority: .background) { [weak self] in
                try? await Task.sleep(for: .seconds(1))  // Give the app a chance to start
                if let self { await self.menuBarManager.addApp(app) }
            }
        }
        
        // Create a cheap kernel watcher for the specified pid
        let src = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        
        src.setEventHandler { [weak self] in
            self?.stopWatching(pid)
        }
        src.resume()
        
        pidWatchers[pid] = src
    }
    
    /// Remove stopped accessory app from monitoring
    private func stopWatching(_ pid: pid_t)  {
        // Make handler idempotent
        guard knownPIDs.remove(pid) != nil else { return }
        
        menuBarManager.removeApp(forPID: pid)
        
        pidWatchers.removeValue(forKey: pid)?.cancel()
    }
}
