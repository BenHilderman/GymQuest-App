//
//  MealLogView.swift
//  GymQuest
//
//  Meal logging view for GymQuest 2.0 Nutrition v1.
//  Quick photo + tags + feeling approach.
//

import SwiftUI
import SwiftData
import PhotosUI

struct MealLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var mealType: MealType = .lunch
    @State private var description = ""
    @State private var selectedTags: Set<String> = []
    @State private var customTag = ""
    @State private var feeling: MealFeeling = .good
    @State private var notes = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var suggestedTags: [String] = []
    @State private var showingCamera = false
    @State private var showLoggedOverlay = false

    private var mealAccent: Color {
        switch mealType {
        case .breakfast: return GQColors.electricGold
        case .lunch: return GQColors.cyanSpark
        case .dinner: return GQColors.vividPurple
        case .snack: return GQColors.success
        case .preworkout: return GQColors.sunsetOrange
        case .postworkout: return GQColors.coralRed
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    GQScreenTitleBlock(
                        title: "Log Meal",
                        subtitle: "Capture what you ate and how it felt.",
                        accent: mealAccent
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    VStack(spacing: 12) {
                        if let photoData = photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .transition(.scale.combined(with: .opacity))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        self.photoData = nil
                                        self.photoItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .padding(8)
                                }
                        } else {
                            HStack(spacing: 16) {
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 24))
                                        Text("Choose Photo")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 104)
                                    .workoutFlowCard(accent: GQColors.cyanSpark)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showingCamera = true
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 24))
                                        Text("Take Photo")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 104)
                                    .workoutFlowCard(accent: GQColors.vividPurple)
                                }
                            }
                            .buttonStyle(GQInteractiveStyle())
                        }
                    }
                    .padding(14)
                    .workoutFlowCard(accent: mealAccent, emphasized: photoData != nil)
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        sectionTitle("Meal Type")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(MealType.allCases, id: \.self) { type in
                                    MealTypeChip(
                                        type: type,
                                        isSelected: mealType == type,
                                        action: {
                                            mealType = type
                                            loadSuggestedTags()
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(14)
                    .workoutFlowCard(accent: mealAccent)
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        sectionTitle("What Did You Eat?")

                        TextField("e.g., Grilled chicken salad with avocado", text: $description)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .padding(14)
                    .workoutFlowCard(accent: mealAccent)
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Quick Tags")

                        FlowLayout(spacing: 8) {
                            ForEach(suggestedTags, id: \.self) { tag in
                                TagChip(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag),
                                    action: {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }
                                )
                            }
                        }

                        // Custom tag input
                        HStack {
                            TextField("Add custom tag...", text: $customTag)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.07))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )

                            Button {
                                if !customTag.isEmpty {
                                    selectedTags.insert(customTag.lowercased())
                                    customTag = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(GQColors.cyanSpark)
                            }
                            .disabled(customTag.isEmpty)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .workoutFlowCard(accent: GQColors.cyanSpark)
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("How Did You Feel?")

                        HStack(spacing: 12) {
                            ForEach(MealFeeling.allCases, id: \.self) { feel in
                                FeelingButton(
                                    feeling: feel,
                                    isSelected: feeling == feel,
                                    action: { feeling = feel }
                                )
                            }
                        }
                    }
                    .padding(14)
                    .workoutFlowCard(accent: GQColors.success)
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        sectionTitle("Notes (Optional)")

                        TextField("Any additional notes...", text: $notes, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .padding(14)
                    .workoutFlowCard(accent: GQColors.vividPurple)
                    .padding(.horizontal, 16)

                    Button {
                        logMeal()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Log Meal")
                        }
                    }
                    .buttonStyle(WorkoutFlowPrimaryButtonStyle(accent: mealAccent))
                    .disabled(description.isEmpty)
                    .opacity(description.isEmpty ? 0.6 : 1)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
                .padding(.bottom, 120)
            }
            .gqPageBackground()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .onAppear {
                loadSuggestedTags()
            }
            #if os(iOS)
            .sheet(isPresented: $showingCamera) {
                CameraView(photoData: $photoData)
            }
            #endif
            .overlay {
                if showLoggedOverlay {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(GQColors.success)
                        Text("Logged!")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(GQColors.surfaceOverlay.opacity(0.72))
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showLoggedOverlay)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(GQColors.textTertiary)
            .tracking(0.5)
    }

    private func loadSuggestedTags() {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)
        suggestedTags = service.getSuggestedTags(userId: profile.id, mealType: mealType)
    }

    private func logMeal() {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)

        _ = service.logMeal(
            userId: profile.id,
            mealType: mealType,
            description: description,
            tags: Array(selectedTags),
            photoData: photoData,
            feeling: feeling,
            notes: notes
        )

        HapticManager.shared.success()
        showLoggedOverlay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct MealTypeChip: View {
    let type: MealType
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color {
        switch type {
        case .breakfast: return GQColors.electricGold
        case .lunch: return GQColors.cyanSpark
        case .dinner: return GQColors.vividPurple
        case .snack: return GQColors.success
        case .preworkout: return GQColors.sunsetOrange
        case .postworkout: return GQColors.coralRed
        }
    }

    var body: some View {
        Button {
            HapticManager.shared.select()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                Text(type.rawValue)
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? accent.opacity(0.85) : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? accent.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.tap()
            action()
        } label: {
            Text(tag)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : GQColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? GQColors.cyanSpark.opacity(0.34) : Color.white.opacity(0.08))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isSelected ? GQColors.cyanSpark.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

struct FeelingButton: View {
    let feeling: MealFeeling
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.select()
            action()
        } label: {
            VStack(spacing: 6) {
                Text(feeling.emoji)
                    .font(.system(size: 24))
                    .scaleEffect(isSelected ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                Text(feeling.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white : GQColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? feeling.color.opacity(0.25) : Color.white.opacity(0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? feeling.color.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}

// MARK: - Camera View

#if os(iOS)
struct CameraView: UIViewControllerRepresentable {
    @Binding var photoData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.photoData = image.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif

// MARK: - Meal Log Card (for HomeView)

struct MealLogCard: View {
    @EnvironmentObject var featureFlags: FeatureFlags
    let onLogMeal: () -> Void

    var body: some View {
        Button(action: onLogMeal) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(GQColors.cyanSpark.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "fork.knife")
                        .font(.title3)
                        .foregroundColor(GQColors.cyanSpark)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("LOG MEAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(GQColors.textTertiary)
                        .tracking(0.5)

                    Text("Track your nutrition")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                Image(systemName: "camera.fill")
                    .font(.title3)
                    .foregroundColor(GQColors.cyanSpark.opacity(0.6))
            }
            .padding(16)
            .background(GQColors.cyanSpark.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(GQColors.cyanSpark.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

// MARK: - Today's Meals View

struct TodaysMealsView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: UserProfile

    @State private var meals: [MealLog] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S MEALS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(GQColors.textTertiary)
                .tracking(0.5)

            if meals.isEmpty {
                HStack {
                    Spacer()
                    Text("No meals logged today")
                        .font(.subheadline)
                        .foregroundColor(GQColors.textTertiary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ForEach(meals) { meal in
                    MealSummaryRow(meal: meal)
                }
            }
        }
        .padding(16)
        .background(GQColors.surfaceBase)
        .cornerRadius(12)
        .onAppear {
            loadMeals()
        }
    }

    private func loadMeals() {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)
        meals = service.getTodaysMeals(userId: profile.id)
    }
}

struct MealSummaryRow: View {
    let meal: MealLog

    var body: some View {
        HStack(spacing: 12) {
            // Photo or icon
            if let photoData = meal.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: meal.mealType.icon)
                        .foregroundColor(GQColors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(meal.mealType.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text(meal.feeling.emoji)
                        .font(.system(size: 12))
                }

                Text(meal.mealDescription)
                    .font(.system(size: 12))
                    .foregroundColor(GQColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(meal.dateTime.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
    }
}

#Preview {
    MealLogView(profile: UserProfile(name: "Ben", username: "ben"))
        .preferredColorScheme(.dark)
}
