//
//  LogoHeaderView.swift
//  lambdas-xi-chapter
//
//  Created by Antigravity on 25/01/2026.
//  Consistent brand header for the top of screens.
//

import SwiftUI

struct LogoHeaderView: View {
    var showDivider: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Image.appLogo
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60) // Adjust height as needed
                    .padding(.vertical, 8)
                Spacer()
            }
            .background(Color.appCard) // Optional: White background for the header area
            
            if showDivider {
                Divider()
            }
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        VStack {
            LogoHeaderView()
            Spacer()
        }
    }
}
