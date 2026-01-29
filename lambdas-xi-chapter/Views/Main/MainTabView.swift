//
//  MainTabView.swift
//  lambdas-xi-chapter
//
//  Main tab navigation §7.1: Discovery, Messages, Bounties, News, Profile
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
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
    }
}

#Preview {
    MainTabView()
}
