//
//  AppDebug.swift
//  lambdas-xi-chapter
//
//  Centralized debug logging. .cursorrules: debug logs for easier debug.
//

import Foundation

/// Debug log that outputs to NSLog (always visible in Console/logs)
func debugLog(_ message: String) {
    #if DEBUG
    // NSLog always appears in logs - more reliable than print() or os_log for debugging
    NSLog("[LPhiE] %@", message)
    #endif
}
