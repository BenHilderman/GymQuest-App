//
//  OfflineHLSDownloadManager.swift
//  GymQuest
//
//  HLS offline download manager using AVAssetDownloadURLSession.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class OfflineHLSDownloadManager: NSObject, ObservableObject {
    @Published var activeDownloads: [UUID: Double] = [:]
    @Published var completedDownloads: [UUID: URL] = [:]
    @Published var failedDownloads: [UUID: Error] = [:]

    var onDownloadComplete: ((UUID, URL) -> Void)?

    private lazy var session: AVAssetDownloadURLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "gymquest.hls.downloads")
        return AVAssetDownloadURLSession(
            configuration: config,
            assetDownloadDelegate: self,
            delegateQueue: .main
        )
    }()

    private var taskToClipId: [URLSessionTask: UUID] = [:]

    func downloadHLS(for clipId: UUID, url: URL) {
        guard activeDownloads[clipId] == nil else { return }

        let asset = AVURLAsset(url: url)

        guard let task = session.makeAssetDownloadTask(
            asset: asset,
            assetTitle: clipId.uuidString,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 500_000]
        ) else {
            return
        }

        task.taskDescription = clipId.uuidString
        taskToClipId[task] = clipId
        task.resume()
        activeDownloads[clipId] = 0.0
    }

    func cancelDownload(for clipId: UUID) {
        session.getAllTasks { tasks in
            for task in tasks {
                if task.taskDescription == clipId.uuidString {
                    task.cancel()
                }
            }
        }
        activeDownloads.removeValue(forKey: clipId)
    }

    func downloadProgress(for clipId: UUID) -> Double {
        activeDownloads[clipId] ?? (completedDownloads[clipId] != nil ? 1.0 : -1)
    }

    func isDownloaded(_ clipId: UUID) -> Bool {
        completedDownloads[clipId] != nil
    }

    func localURL(for clipId: UUID) -> URL? {
        completedDownloads[clipId]
    }
}

extension OfflineHLSDownloadManager: AVAssetDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        guard let idString = assetDownloadTask.taskDescription,
              let clipId = UUID(uuidString: idString) else { return }

        let loaded = loadedTimeRanges
            .map { $0.timeRangeValue.duration.seconds }
            .reduce(0, +)

        let expected = timeRangeExpectedToLoad.duration.seconds
        let progress = expected > 0 ? loaded / expected : 0

        Task { @MainActor in
            self.activeDownloads[clipId] = min(max(progress, 0), 1)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let idString = assetDownloadTask.taskDescription,
              let clipId = UUID(uuidString: idString) else { return }

        Task { @MainActor in
            self.activeDownloads.removeValue(forKey: clipId)
            self.completedDownloads[clipId] = location
            self.onDownloadComplete?(clipId, location)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let idString = task.taskDescription,
              let clipId = UUID(uuidString: idString) else { return }

        if let error = error {
            Task { @MainActor in
                self.activeDownloads.removeValue(forKey: clipId)
                self.failedDownloads[clipId] = error
            }
        }
    }
}
