//
//  NewsPost.swift
//  lambdas-xi-chapter
//
//  News / Legacy §13. Text, images, newsletter-style. Read-only for users.
//

import Foundation

struct NewsPost: Identifiable {
    var id: UUID
    var title: String
    var body: String?
    var imageURL: String?
    /// Newsletter-style: PDF URL or extracted content. Read-only §13.3.
    var pdfURL: String?
    var authorName: String?
    var publishedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        body: String? = nil,
        imageURL: String? = nil,
        pdfURL: String? = nil,
        authorName: String? = nil,
        publishedAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.imageURL = imageURL
        self.pdfURL = pdfURL
        self.authorName = authorName
        self.publishedAt = publishedAt
        self.createdAt = createdAt
    }
}
