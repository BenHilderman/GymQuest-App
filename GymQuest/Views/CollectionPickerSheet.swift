import SwiftUI
import SwiftData

/// Long-press on a card's save button opens this. Two built-in destinations
/// (Do soon / Watch later) and a freeform field for ad-hoc named playlists.
struct CollectionPickerSheet: View {
    let post: Post
    let userId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allSaves: [SavedWorkout]

    @State private var newCollectionName: String = ""
    @FocusState private var newFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Save \"\(displayTitle)\" to:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(GQColors.textSecondary)

                    builtInRow(
                        title: "Do soon",
                        subtitle: "Workouts to run later",
                        icon: "figure.strengthtraining.traditional",
                        collection: .train,
                        customName: nil
                    )
                    builtInRow(
                        title: "Watch later",
                        subtitle: "Clips for the couch",
                        icon: "play.rectangle.fill",
                        collection: .watch,
                        customName: nil
                    )

                    if !customCollectionNames.isEmpty {
                        Text("Your collections")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(GQColors.textTertiary)
                            .padding(.top, 8)

                        ForEach(customCollectionNames, id: \.self) { name in
                            builtInRow(
                                title: name,
                                subtitle: "\(savedCount(in: name)) item\(savedCount(in: name) == 1 ? "" : "s")",
                                icon: "bookmark.fill",
                                collection: .custom,
                                customName: name
                            )
                        }
                    }

                    Divider().padding(.vertical, 4)

                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(GQColors.accent)
                            .font(.system(size: 16))
                        TextField("New collection name", text: $newCollectionName)
                            .focused($newFieldFocused)
                            .submitLabel(.done)
                            .onSubmit(saveToNewCollection)
                            .font(.system(size: 14))
                        if !newCollectionName.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Save") { saveToNewCollection() }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(GQGradients.primary))
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(GQColors.surfaceSecondary))
                }
                .padding(16)
            }
            .gqPageBackground()
            .navigationTitle("Save")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Subviews

    private func builtInRow(
        title: String,
        subtitle: String,
        icon: String,
        collection: SavedCollection,
        customName: String?
    ) -> some View {
        let isAlreadySaved = isSaved(collection: collection, customName: customName)
        return Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            toggleSave(collection: collection, customName: customName)
            if !isAlreadySaved { dismiss() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(GQColors.accent.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GQColors.textPrimary)
                    Text(subtitle).font(.system(size: 11)).foregroundColor(GQColors.textSecondary)
                }
                Spacer()
                Image(systemName: isAlreadySaved ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isAlreadySaved ? GQColors.accent : GQColors.textTertiary)
                    .font(.system(size: 18))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(GQColors.surfaceSecondary))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived

    private var displayTitle: String {
        if let highlight = post.exerciseHighlight { return highlight }
        if !post.caption.isEmpty { return post.caption }
        return post.workoutType ?? "this post"
    }

    private var customCollectionNames: [String] {
        let mySaves = allSaves.filter { $0.userId == userId && $0.collection == .custom }
        let names = Set(mySaves.compactMap { $0.customCollectionName })
        return names.sorted()
    }

    private func savedCount(in name: String) -> Int {
        allSaves.filter { $0.userId == userId && $0.collection == .custom && $0.customCollectionName == name }.count
    }

    private func isSaved(collection: SavedCollection, customName: String?) -> Bool {
        allSaves.contains {
            $0.userId == userId && $0.postId == post.id && $0.collection == collection &&
            $0.customCollectionName == customName
        }
    }

    private func toggleSave(collection: SavedCollection, customName: String?) {
        let matches = allSaves.filter {
            $0.userId == userId && $0.postId == post.id && $0.collection == collection &&
            $0.customCollectionName == customName
        }
        if let existing = matches.first {
            modelContext.delete(existing)
        } else {
            let saved = SavedWorkout(
                userId: userId,
                postId: post.id,
                collection: collection,
                customCollectionName: customName
            )
            modelContext.insert(saved)
        }
        try? modelContext.save()
    }

    private func saveToNewCollection() {
        let name = newCollectionName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        toggleSave(collection: .custom, customName: name)
        newCollectionName = ""
        newFieldFocused = false
        dismiss()
    }
}
