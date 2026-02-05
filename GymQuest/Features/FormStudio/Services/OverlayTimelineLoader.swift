//
//  OverlayTimelineLoader.swift
//  GymQuest
//
//  Loads overlay timeline events for broadcast-style callouts on videos.
//

import Foundation

struct OverlayEvent: Codable, Identifiable {
    var id: UUID = UUID()
    let start: Double
    let end: Double
    let text: String
    let anchor: String

    enum CodingKeys: String, CodingKey {
        case start, end, text, anchor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.start = try container.decode(Double.self, forKey: .start)
        self.end = try container.decode(Double.self, forKey: .end)
        self.text = try container.decode(String.self, forKey: .text)
        self.anchor = try container.decode(String.self, forKey: .anchor)
    }

    init(start: Double, end: Double, text: String, anchor: String = "bottom") {
        self.id = UUID()
        self.start = start
        self.end = end
        self.text = text
        self.anchor = anchor
    }
}

enum OverlayAnchor: String {
    case top, center, bottom

    static func from(_ string: String) -> OverlayAnchor {
        OverlayAnchor(rawValue: string.lowercased()) ?? .bottom
    }
}

struct OverlayTimelineLoader {

    static func load(from url: URL) async throws -> [OverlayEvent] {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([OverlayEvent].self, from: data)
    }

    static func loadFromBundle(named filename: String) -> [OverlayEvent] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([OverlayEvent].self, from: data) else {
            return []
        }
        return events
    }

    static func sampleEvents() -> [OverlayEvent] {
        [
            OverlayEvent(start: 0.0, end: 2.5, text: "Set seat so handles align mid-chest", anchor: "top"),
            OverlayEvent(start: 3.0, end: 5.5, text: "Retract shoulder blades", anchor: "center"),
            OverlayEvent(start: 6.0, end: 8.5, text: "Control the eccentric", anchor: "bottom"),
            OverlayEvent(start: 10.0, end: 12.5, text: "Drive through full range", anchor: "bottom")
        ]
    }
}
