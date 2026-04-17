import Foundation
#if canImport(UIKit)
import UIKit
import AVFoundation

/// Pulls a representative frame from a video so previews show real exercise
/// footage instead of procedural placeholders. Cached per-resource-name so
/// the AVAssetImageGenerator only runs once per demo clip.
///
/// Not @MainActor — AVAssetImageGenerator is thread-safe and we want callers
/// (like MockDataSeeder) to invoke it from any context.
enum VideoThumbnailService {

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [String: Data] = [:]

    /// Extract a JPEG-encoded thumbnail (~600×600 max) from a bundled video
    /// resource. Returns nil if the resource isn't found or generation
    /// fails. Synchronous + on the main actor — fine for seeder use where
    /// we run this once per app install.
    static func thumbnail(forResource name: String, withExtension ext: String = "mp4") -> Data? {
        cacheLock.lock()
        let cached = cache[name]
        cacheLock.unlock()
        if let cached { return cached }

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            return nil
        }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        // Sample at ~1 second in to skip black/intro frames common at t=0.
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            guard let data = uiImage.jpegData(compressionQuality: 0.7) else { return nil }
            cacheLock.lock()
            cache[name] = data
            cacheLock.unlock()
            return data
        } catch {
            return nil
        }
    }
}
#endif
