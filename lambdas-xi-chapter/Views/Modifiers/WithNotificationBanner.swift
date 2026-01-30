//
//  WithNotificationBanner.swift
//  lambdas-xi-chapter
//
//  View modifier for applying the in-app notification banner.
//
//

import SwiftUI

struct WithNotificationBanner: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                InAppNotificationBanner()
            }
    }
}

extension View {
    /// Applies the in-app notification banner overlay to the view
    func withNotificationBanner() -> some View {
        modifier(WithNotificationBanner())
    }
}
