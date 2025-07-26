//
//  Helpers.swift
//  BarTap
//

import SwiftUI

/// Execute work synchronously on the main queue if we are not already there
@inline(__always)
func onMain<T>(_ work: () -> T) -> T {
    if Thread.isMainThread {
        return work()
    } else {
        return DispatchQueue.main.sync(execute: work)
    }
}
