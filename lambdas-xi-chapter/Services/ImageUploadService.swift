//
//  ImageUploadService.swift
//  lambdas-xi-chapter
//
//  Handles image upload to Supabase Storage for chat attachments.
//  §12 Messaging - photo attachments support.
//  Debug: Compresses images before upload, returns public URL.
//

import Foundation
import UIKit
import Supabase

// MARK: - Image Upload Errors

/// Errors that can occur during image upload
/// Debug: Provides specific error messages for debugging
enum ImageUploadError: LocalizedError {
    case noClient
    case compressionFailed
    case uploadFailed(String)
    case urlGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .noClient:
            return "Supabase client not configured"
        case .compressionFailed:
            return "Failed to compress image"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .urlGenerationFailed:
            return "Failed to generate image URL"
        }
    }
}

// MARK: - Image Upload Service

/// Service for uploading images to Supabase Storage
/// Debug: Handles compression, upload, and URL generation
final class ImageUploadService {
    static let shared = ImageUploadService()
    
    // MARK: - Constants
    
    /// Storage bucket name for chat images
    /// Debug: Must be created in Supabase Dashboard
    private let bucketName = "chat-images"
    
    /// Maximum image dimension (width or height)
    private let maxDimension: CGFloat = 1200
    
    /// JPEG compression quality (0.0 - 1.0)
    private let compressionQuality: CGFloat = 0.7
    
    /// Maximum file size in bytes (5MB)
    private let maxFileSize = 5 * 1024 * 1024
    
    // MARK: - Initialization
    
    private init() {
        debugLog("ImageUploadService: init")
    }
    
    // MARK: - Public Methods
    
    /// Upload an image for a chat message
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - chatId: The chat ID (used for organizing files)
    /// - Returns: The public URL of the uploaded image
    /// Debug: Compresses image, uploads to Supabase Storage, returns URL
    func uploadChatImage(_ image: UIImage, chatId: UUID) async throws -> URL {
        guard let client = SupabaseConfig.client else {
            debugLog("ImageUploadService: no Supabase client")
            throw ImageUploadError.noClient
        }
        
        debugLog("ImageUploadService: starting upload for chat \(chatId)")
        
        // Compress the image
        guard let imageData = compressImage(image) else {
            debugLog("ImageUploadService: compression failed")
            throw ImageUploadError.compressionFailed
        }
        
        debugLog("ImageUploadService: compressed image size: \(imageData.count) bytes")
        
        // Generate unique filename
        let filename = "\(chatId.uuidString)/\(UUID().uuidString).jpg"
        
        do {
            // Upload to Supabase Storage using current API
            try await client.storage
                .from(bucketName)
                .upload(
                    filename,
                    data: imageData,
                    options: FileOptions(
                        contentType: "image/jpeg"
                    )
                )
            
            debugLog("ImageUploadService: upload successful, path: \(filename)")
            
            // Get the public URL
            let urlString = try client.storage
                .from(bucketName)
                .getPublicURL(path: filename)
                .absoluteString
            
            guard let url = URL(string: urlString) else {
                throw ImageUploadError.urlGenerationFailed
            }
            
            debugLog("ImageUploadService: public URL generated: \(url)")
            return url
            
        } catch let error as ImageUploadError {
            throw error
        } catch {
            debugLog("ImageUploadService: upload error - \(error)")
            throw ImageUploadError.uploadFailed(error.localizedDescription)
        }
    }
    
    /// Delete an image from storage
    /// - Parameter path: The storage path of the image
    /// Debug: Use for cleanup or message deletion
    func deleteImage(path: String) async throws {
        guard let client = SupabaseConfig.client else {
            throw ImageUploadError.noClient
        }
        
        debugLog("ImageUploadService: deleting image at path: \(path)")
        
        try await client.storage
            .from(bucketName)
            .remove(paths: [path])
        
        debugLog("ImageUploadService: image deleted")
    }
    
    // MARK: - Private Methods
    
    /// Compress and resize image for upload
    /// - Parameter image: Original UIImage
    /// - Returns: Compressed JPEG data, or nil if compression failed
    /// Debug: Resizes to maxDimension, compresses to target quality
    private func compressImage(_ image: UIImage) -> Data? {
        debugLog("ImageUploadService: compressing image, original size: \(image.size)")
        
        // Resize if needed
        let resizedImage = resizeImageIfNeeded(image)
        
        // Try compression at target quality
        var quality = compressionQuality
        var imageData = resizedImage.jpegData(compressionQuality: quality)
        
        // Reduce quality if still too large
        while let data = imageData, data.count > maxFileSize, quality > 0.1 {
            quality -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: quality)
            debugLog("ImageUploadService: reducing quality to \(quality), size: \(data.count)")
        }
        
        if let data = imageData {
            debugLog("ImageUploadService: final compressed size: \(data.count) bytes")
        }
        
        return imageData
    }
    
    /// Resize image if it exceeds maximum dimension
    /// - Parameter image: Original UIImage
    /// - Returns: Resized UIImage
    /// Debug: Maintains aspect ratio
    private func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
        let size = image.size
        
        // Check if resize is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        debugLog("ImageUploadService: resizing from \(size) to \(newSize)")
        
        // Render at new size
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    /// Extract storage path from public URL
    /// - Parameter url: Public URL returned from upload
    /// - Returns: The storage path for deletion
    /// Debug: Parses the Supabase Storage URL format
    func extractPath(from url: URL) -> String? {
        // Supabase Storage URLs format:
        // https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>
        let components = url.pathComponents
        
        // Find the bucket name and extract path after it
        if let bucketIndex = components.firstIndex(of: bucketName),
           bucketIndex < components.count - 1 {
            let pathComponents = components[(bucketIndex + 1)...]
            return pathComponents.joined(separator: "/")
        }
        
        return nil
    }
}

// MARK: - Convenience Extensions

extension UIImage {
    /// Convenience method to check if image is large
    var isLarge: Bool {
        size.width > 1200 || size.height > 1200
    }
    
    /// Estimated file size in bytes (rough estimate)
    var estimatedFileSize: Int {
        guard let data = jpegData(compressionQuality: 0.7) else { return 0 }
        return data.count
    }
}
