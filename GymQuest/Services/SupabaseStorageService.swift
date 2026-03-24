//
//  SupabaseStorageService.swift
//  GymQuest
//
//  Handles media upload/download to Supabase Storage buckets.
//

import Foundation
import Supabase

@MainActor
final class SupabaseStorageService {
    static let shared = SupabaseStorageService()

    private init() {}

    // MARK: - Upload

    func uploadPostMedia(postId: UUID, imageData: Data) async throws -> String {
        let path = "\(postId.uuidString)/photo.jpg"
        try await SupabaseConfig.client.storage
            .from("post-media")
            .upload(
                path: path,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        return getPublicURL(bucket: "post-media", path: path)
    }

    func uploadProfilePhoto(userId: UUID, imageData: Data) async throws -> String {
        let path = "\(userId.uuidString)/avatar.jpg"
        try await SupabaseConfig.client.storage
            .from("profile-photos")
            .upload(
                path: path,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        return getPublicURL(bucket: "profile-photos", path: path)
    }

    // MARK: - Public URL

    func getPublicURL(bucket: String, path: String) -> String {
        let url = try? SupabaseConfig.client.storage
            .from(bucket)
            .getPublicURL(path: path)
        return url?.absoluteString ?? ""
    }
}
