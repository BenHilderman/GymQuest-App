import XCTest
@testable import GymQuest

final class PostMediaTests: XCTestCase {

    // MARK: - PostMedia JSON round-trip

    func testPostMedia_encodesAndDecodesPhotoRoundTrip() throws {
        let original = PostMedia(
            exerciseName: "Bench Press",
            exerciseIndex: 2,
            mediaType: .photo,
            data: Data([0x01, 0x02, 0x03]),
            thumbnailData: nil,
            caption: "Top set"
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PostMedia.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.exerciseName, "Bench Press")
        XCTAssertEqual(decoded.exerciseIndex, 2)
        XCTAssertEqual(decoded.mediaType, .photo)
        XCTAssertEqual(decoded.caption, "Top set")
        XCTAssertEqual(decoded.data, Data([0x01, 0x02, 0x03]))
    }

    func testPostMedia_encodesAndDecodesVideoWithThumbnail() throws {
        let original = PostMedia(
            exerciseName: nil,
            exerciseIndex: nil,
            mediaType: .video,
            data: Data([0xAA, 0xBB]),
            thumbnailData: Data([0xCC, 0xDD]),
            caption: nil
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PostMedia.self, from: encoded)

        XCTAssertEqual(decoded.mediaType, .video)
        XCTAssertEqual(decoded.data, Data([0xAA, 0xBB]))
        XCTAssertEqual(decoded.thumbnailData, Data([0xCC, 0xDD]))
        XCTAssertNil(decoded.exerciseName)
        XCTAssertNil(decoded.caption)
    }

    func testPostMedia_arrayPreservesOrder() throws {
        let items: [PostMedia] = (0..<6).map {
            PostMedia(
                exerciseIndex: $0,
                mediaType: $0 % 2 == 0 ? .photo : .video,
                caption: "Clip \($0)"
            )
        }
        let encoded = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([PostMedia].self, from: encoded)

        XCTAssertEqual(decoded.count, 6)
        for i in 0..<6 {
            XCTAssertEqual(decoded[i].exerciseIndex, i)
            XCTAssertEqual(decoded[i].caption, "Clip \(i)")
            XCTAssertEqual(decoded[i].mediaType, items[i].mediaType)
        }
    }

    // MARK: - SerializedMediaItem round-trip (Supabase carousel metadata)

    func testSerializedMediaItem_capturesTypeCaptionAndOrder() throws {
        let media = PostMedia(
            exerciseName: "Squat",
            exerciseIndex: 1,
            mediaType: .video,
            caption: "Finisher"
        )
        let serialized = SerializedMediaItem(from: media, order: 3)
        let data = try JSONEncoder().encode(serialized)
        let decoded = try JSONDecoder().decode(SerializedMediaItem.self, from: data)

        XCTAssertEqual(decoded.id, media.id)
        XCTAssertEqual(decoded.mediaType, "video")
        XCTAssertEqual(decoded.caption, "Finisher")
        XCTAssertEqual(decoded.exerciseName, "Squat")
        XCTAssertEqual(decoded.exerciseIndex, 1)
        XCTAssertEqual(decoded.order, 3)
    }

    func testSerializedMediaItem_arrayPreservesExplicitOrder() throws {
        let items: [PostMedia] = [
            PostMedia(mediaType: .photo, caption: "Warm-up"),
            PostMedia(mediaType: .video, caption: "Top set"),
            PostMedia(mediaType: .video, caption: "Finisher")
        ]
        let serialized = items.enumerated().map { SerializedMediaItem(from: $1, order: $0) }
        let data = try JSONEncoder().encode(serialized)
        let decoded = try JSONDecoder().decode([SerializedMediaItem].self, from: data)

        XCTAssertEqual(decoded.map(\.order), [0, 1, 2])
        XCTAssertEqual(decoded.map(\.caption), ["Warm-up", "Top set", "Finisher"])
        XCTAssertEqual(decoded.map(\.mediaType), ["photo", "video", "video"])
    }

    // MARK: - Primary-type routing parity (first-media-wins rule)
    // Mirrors the postPrimaryType helper in ProfileView: the first mediaItem
    // decides whether a post shows up in the photo or clip tab. This keeps
    // the tab filter behavior pinned even as the helper moves or gets inlined.

    func testPrimaryType_firstMediaItemWinsOverLegacyFields() {
        let items = [
            PostMedia(mediaType: .video),
            PostMedia(mediaType: .photo)
        ]
        XCTAssertEqual(items.first?.mediaType, .video)
    }

    func testPrimaryType_emptyMediaItemsFallsBack() {
        let items: [PostMedia] = []
        XCTAssertNil(items.first?.mediaType)
    }

    // Regression: legacy single-video posts carry a thumbnail in photoData
    // alongside the real videoData. The tab-routing helper must classify
    // them as video, otherwise they leak into the Photos tab.
    func testPrimaryType_legacyVideoWithCoverThumbnailRoutesAsVideo() {
        let post = Post(
            authorId: UUID(),
            authorName: "Tester",
            authorUsername: "tester",
            caption: "single-clip post",
            photoData: Data([0xCC]),  // cover thumbnail
            videoData: Data([0xDD])   // actual video
        )

        // Mirrors ProfileView.postPrimaryType priority:
        //   mediaItems.first → videoData → photoData
        let primary: PostMedia.PostMediaType? = {
            if let first = post.mediaItems.first { return first.mediaType }
            if post.videoData != nil { return .video }
            if post.photoData != nil { return .photo }
            return nil
        }()

        XCTAssertEqual(primary, .video)
    }
}
