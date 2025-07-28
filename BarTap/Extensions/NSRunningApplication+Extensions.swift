//
//  NSRunningApplication+Extensions.swift
//  BarTap
//

import SwiftUI

extension NSRunningApplication {
    /// Asynchronously waits for the application to finish launching
    func waitForFinishedLaunching(timeout: TimeInterval = 10.0) async {
        let start = Date()
        
        // Poll the property until it's true or the timeout is exceeded
        while !self.isFinishedLaunching {
            if Date().timeIntervalSince(start) > timeout {
                return
            }
            
            // Wait for 50 milliseconds before checking again
            try? await Task.sleep(for: .milliseconds(50))
        }
        
        return
    }
    
    struct TimeoutError: Error, LocalizedError {
        var errorDescription: String? = "The operation timed out."
    }
}
