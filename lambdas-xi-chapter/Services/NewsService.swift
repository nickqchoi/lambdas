//
//  NewsService.swift
//  lambdas-xi-chapter
//
//  News / Legacy §13. Read-only. Supabase when configured; else mock. §13.3 Admin posts via backend.
//

import Foundation
import Combine
import Supabase

final class NewsService: ObservableObject {
    static let shared = NewsService()

    @Published private(set) var posts: [NewsPost] = []

    private init() {
        debugLog("NewsService: init")
    }

    func fetchPosts() async -> [NewsPost] {
        if let c = SupabaseConfig.client {
            do {
                let list: [NewsPost] = try await c.from("news_posts").select().order("posted_at", ascending: false).execute().value
                await MainActor.run { posts = list }
                return list
            } catch { debugLog("NewsService: fetchPosts \(error)"); return posts }
        }
        return posts.sorted { $0.publishedAt > $1.publishedAt }
    }

    func seedMockNews() {
        guard posts.isEmpty else { return }
        posts = [
            NewsPost(
                id: UUID(),
                title: "Spring 2026 Rush Recap",
                body: "Another great rush season! Thanks to all actives and alumni who helped make it happen. We welcomed 12 new members to our chapter. Special shout-out to the recruitment committee for organizing amazing events.",
                imageURL: "photo1",
                authorName: "Chapter Leadership",
                publishedAt: Date().addingTimeInterval(-86400 * 5)
            ),
            NewsPost(
                id: UUID(),
                title: "Alumni Networking Night - March 15",
                body: "Join us March 15 at the chapter house for an evening of networking and updates. This is a great opportunity to reconnect with brothers and learn about career opportunities. Light refreshments will be served. RSVP by March 10.",
                authorName: "Programming Chair",
                publishedAt: Date().addingTimeInterval(-86400 * 2)
            ),
            NewsPost(
                id: UUID(),
                title: "Welcome New Officers",
                body: "Congratulations to the new executive board! We're excited for the year ahead and the fresh perspective you bring. Thank you to the outgoing officers for their dedication and service.",
                authorName: "President",
                publishedAt: Date().addingTimeInterval(-86400 * 10)
            ),
        ]
        debugLog("NewsService: seeded \(posts.count) mock news posts")
    }
}
