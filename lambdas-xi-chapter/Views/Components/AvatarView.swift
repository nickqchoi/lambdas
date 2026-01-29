//
//  AvatarView.swift
//  lambdas-xi-chapter
//
//  Standardized avatar component that handles both profile photos and initial fallbacks.
//

import SwiftUI
import Kingfisher

struct AvatarView: View {
    let photoURL: String?
    let initials: String
    let size: CGFloat
    let backgroundColor: Color
    
    init(photoURL: String?, initials: String, size: CGFloat = 40, backgroundColor: Color = .blue.opacity(0.2)) {
        self.photoURL = photoURL
        self.initials = initials
        self.size = size
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        Group {
            if let urlString = photoURL, let url = URL(string: urlString) {
                KFImage(url)
                    .resizable()
                    .placeholder {
                        fallbackView
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallbackView
            }
        }
    }
    
    private var fallbackView: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: size, height: size)
            .overlay {
                Text(initials.prefix(2).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.primary)
            }
    }
}

#Preview {
    HStack {
        AvatarView(photoURL: nil, initials: "AC", size: 60)
        AvatarView(photoURL: "https://via.placeholder.com/150", initials: "JS", size: 60)
    }
}
