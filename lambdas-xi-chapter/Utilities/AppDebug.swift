//
//  AppDebug.swift
//  lambdas-xi-chapter
//
//  Centralized debug logging. .cursorrules: debug logs for easier debug.
//

import Foundation

func debugLog(_ message: String) {
    #if DEBUG
    print("[LPhiE] \(message)")
    #endif
}
