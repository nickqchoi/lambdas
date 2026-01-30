//
//  MainTabView.swift
//  lambdas-xi-chapter
//
//  Main tab navigation §7.1: Discovery, Messages, Bounties, News, Profile
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var notificationService = InAppNotificationService.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoveryView()
                .tabItem {
                    Label("Discovery", systemImage: "person.2.fill")
                }
                .tag(0)
            
            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(1)
            
            BountiesView()
                .tabItem {
                    Label("Bounties", systemImage: "list.bullet.clipboard.fill")
                }
                .tag(2)
            
            NewsView()
                .tabItem {
                    Label("News", systemImage: "newspaper.fill")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(Color.appPrimary)
        .onChange(of: notificationService.navigateToChat) { _, chatId in
            if chatId != nil {
                selectedTab = 1 // Switch to Messages tab
            }
        }
    }
}

#Preview {
    MainTabView()
}
