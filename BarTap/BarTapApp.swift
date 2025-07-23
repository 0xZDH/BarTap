//
//  BarTapApp.swift
//  BarTap
//
// View unified logs for this application:
//   log stream --level debug --predicate 'subsystem == "com.github.0xZDH.BarTap"'

import SwiftUI

@main
struct BarTapApp: App {
    //@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No window scene, menu bar only
        }
    }
}
