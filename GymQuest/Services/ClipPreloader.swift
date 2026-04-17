import Foundation

/// Pre-writes video data to temp files in the background so
/// `ScrollClipVideoPlayer` can skip the synchronous file write and
/// start playback instantly. Thread-safe via NSLock so the video player
/// can read the cache synchronously without bridging to an actor.
final class ClipPreloader: @unchecked Sendable {
    static let shared = ClipPreloader()
    private init() {}

    private let lock = NSLock()
    private var cache: [UUID: URL] = [:]

    /// Returns the cached temp URL, or nil if not preloaded yet.
    func cachedURL(for postId: UUID) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return cache[postId]
    }

    /// Pre-write video bytes in the background for upcoming clips.
    func preload(posts: [(id: UUID, videoData: Data)]) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            for entry in posts {
                lock.lock()
                let alreadyCached = cache[entry.id] != nil
                lock.unlock()
                guard !alreadyCached else { continue }

                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("prebuf_\(entry.id.uuidString).mov")
                if !FileManager.default.fileExists(atPath: url.path) {
                    try? entry.videoData.write(to: url)
                }
                lock.lock()
                cache[entry.id] = url
                lock.unlock()
            }
        }
    }

    /// Retire entries far behind the viewport.
    func evict(postIds: [UUID]) {
        lock.lock()
        for id in postIds {
            if let url = cache.removeValue(forKey: id) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        lock.unlock()
    }
}
