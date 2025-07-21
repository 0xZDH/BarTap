//
//  BarTapApp.swift
//  BarTap
//

/*

 View NSLog() logging:
   log show --predicate 'process == "BarTap"' --style syslog --last 10m

 Codesign:
   codesign --deep --force --sign "BarTapDev" BarTapBuilds/BarTap/BarTap.app

 */

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
