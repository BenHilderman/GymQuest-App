import TVServices

class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent() async -> TVTopShelfContent? {
        let content = TVTopShelfSectionedContent(sections: [
            makeRecentWorkoutsSection(),
            makeChallengesSection()
        ])
        return content
    }

    // MARK: - Sections

    private func makeRecentWorkoutsSection() -> TVTopShelfItemCollection<TVTopShelfSectionedItem> {
        let section = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: [
            makeItem(id: "push", title: "Push Day — 45 min • 12,400 lbs"),
            makeItem(id: "pull", title: "Pull Day — 52 min • 15,200 lbs"),
            makeItem(id: "legs", title: "Leg Day — 60 min • 22,800 lbs"),
            makeItem(id: "upper", title: "Upper Body — 48 min • 14,100 lbs"),
            makeItem(id: "cardio", title: "Cardio — 30 min • 320 cal")
        ])
        section.title = "Recent Workouts"
        return section
    }

    private func makeChallengesSection() -> TVTopShelfItemCollection<TVTopShelfSectionedItem> {
        let section = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: [
            makeItem(id: "squat-challenge", title: "30-Day Squat Challenge — Day 18 of 30"),
            makeItem(id: "bench-club", title: "Bench 225 Club — Current: 215 lbs"),
            makeItem(id: "streak", title: "Streak Challenge — 12 days and counting")
        ])
        section.title = "Active Challenges"
        return section
    }

    // MARK: - Item Builder

    private func makeItem(id: String, title: String) -> TVTopShelfSectionedItem {
        let item = TVTopShelfSectionedItem(identifier: id)
        item.title = title
        item.playAction = TVTopShelfAction(url: URL(string: "liftai://workout/\(id)")!)
        item.displayAction = TVTopShelfAction(url: URL(string: "liftai://workout/\(id)")!)
        item.setImageURL(Bundle.main.url(forResource: "TopShelf", withExtension: "png"), for: .screenScale1x)
        return item
    }
}
