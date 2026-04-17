import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Post-workout prompt: "You just finished! Log a quick check-in?" One
/// optional line, one tap to post. Cheaper than the full post editor so
/// people actually do it.
struct CheckInPromptSheet: View {
    let profile: UserProfile
    let workoutType: String
    let durationMinutes: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var note: String = ""
    @FocusState private var noteFocused: Bool

    private let quickNotes: [String] = [
        "Felt strong",
        "Tough but fine",
        "Barely survived",
        "Best session in a while",
        "Light day",
        ""   // blank — no note, just check in
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                headline
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                quickTags
                    .padding(.horizontal, 20)

                TextField("Add a note (optional)", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($noteFocused)
                    .font(.system(size: 14))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(GQColors.surfaceSecondary))
                    .padding(.horizontal, 20)

                Spacer()

                Button(action: postCheckIn) {
                    Text("Post check-in")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(GQGradients.primary))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .gqPageBackground()
            .navigationTitle("Check in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nice work.")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(GQColors.textPrimary)
            Text("\(workoutType.capitalized) · \(durationMinutes) min")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(GQColors.textSecondary)
        }
    }

    private var quickTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(quickNotes.filter { !$0.isEmpty }, id: \.self) { tag in
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        note = tag
                    } label: {
                        Text(tag)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(GQColors.surfaceSecondary))
                            .foregroundColor(GQColors.textPrimary)
                            .overlay(Capsule().stroke(GQColors.borderDefault.opacity(0.5), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func postCheckIn() {
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        let checkIn = WorkoutCheckIn(
            userId: profile.id,
            userName: profile.name,
            userUsername: profile.username,
            workoutType: workoutType,
            durationMinutes: durationMinutes,
            note: trimmed.isEmpty ? nil : trimmed
        )
        modelContext.insert(checkIn)
        try? modelContext.save()
        dismiss()
    }
}
