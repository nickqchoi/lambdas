//
//  NewsView.swift
//  lambdas-xi-chapter
//
//  News feed §13: read-only posts with text/images.
//

import SwiftUI

struct NewsView: View {
    @StateObject private var newsService = NewsService.shared
    
    @State private var posts: [NewsPost] = []
    @State private var isLoading = false
    @State private var selectedPost: NewsPost?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading news...")
                } else if posts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No news yet")
                            .font(.headline)
                        Text("Check back later for updates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Invisible anchor for scrolling to top
                                Color.clear
                                    .frame(height: 1)
                                    .id("top")
                                
                                ForEach(posts) { post in
                                    NewsCardView(post: post) {
                                        selectedPost = post
                                    }
                                }
                            }
                            .padding()
                        }
                        .refreshable {
                            loadPosts()
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            withAnimation {
                                proxy.scrollTo("top", anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle("News")
            .sheet(item: $selectedPost) { post in
                NewsDetailView(post: post)
            }
            .task {
                loadPosts()
            }
        }
    }
    
    private func loadPosts() {
        isLoading = true
        Task {
            let result = await newsService.fetchPosts()
            await MainActor.run {
                posts = result
                isLoading = false
            }
        }
    }
}

struct NewsCardView: View {
    let post: NewsPost
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Featured image placeholder
                if post.imageURL != nil {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 180)
                        .cornerRadius(12)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    
                    if let body = post.body {
                        Text(body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    
                    HStack {
                        if let author = post.authorName {
                            AvatarView(
                                photoURL: nil,
                                initials: author,
                                size: 20
                            )
                            Text(author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(post.publishedAt, format: .dateTime.month().day().year())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct NewsDetailView: View {
    let post: NewsPost
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Featured image
                    if post.imageURL != nil {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 250)
                            .cornerRadius(12)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.white)
                            }
                    }
                    
                    // Title
                    Text(post.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Author & Date
                    HStack {
                        if let author = post.authorName {
                            AvatarView(
                                photoURL: nil,
                                initials: author,
                                size: 30
                            )
                            Text(author)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Text(post.publishedAt, format: .dateTime.month().day().year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Body
                    if let body = post.body {
                        Text(body)
                            .font(.body)
                            .lineSpacing(8)
                    }
                }
                .padding()
            }
            .navigationTitle("News")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NewsView()
}
