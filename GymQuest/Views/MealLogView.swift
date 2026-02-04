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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Photo section
                    VStack(spacing: 12) {
                        if let photoData = photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        self.photoData = nil
                                        self.photoItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
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
                                            .font(.system(size: 32))
                                        Text("Choose Photo")
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }

                                Button {
                                    showingCamera = true
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 32))
                                        Text("Take Photo")
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Meal type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MEAL TYPE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)

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
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHAT DID YOU EAT?")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)

                        TextField("e.g., Grilled chicken salad with avocado", text: $description)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("QUICK TAGS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)

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
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)

                            Button {
                                if !customTag.isEmpty {
                                    selectedTags.insert(customTag.lowercased())
                                    customTag = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .disabled(customTag.isEmpty)
                        }
                    }

                    // How did you feel?
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HOW DID YOU FEEL?")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)

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

                    // Notes (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES (OPTIONAL)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)

                        TextField("Any additional notes...", text: $notes, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    // Log button
                    Button {
                        logMeal()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Log Meal")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(description.isEmpty)

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Log Meal")
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
        }
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

        dismiss()
    }
}

// MARK: - Supporting Views

struct MealTypeChip: View {
    let type: MealType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                Text(type.rawValue)
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white : Color.white.opacity(0.1))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue.opacity(0.4) : Color.white.opacity(0.08))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct FeelingButton: View {
    let feeling: MealFeeling
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(feeling.emoji)
                    .font(.system(size: 28))
                Text(feeling.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? feeling.color.opacity(0.3) : Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? feeling.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "fork.knife")
                        .font(.title3)
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("LOG MEAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(0.5)

                    Text("Track your nutrition")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                Image(systemName: "camera.fill")
                    .font(.title3)
                    .foregroundColor(.green.opacity(0.6))
            }
            .padding(16)
            .background(Color.green.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                .foregroundColor(.gray)
                .tracking(0.5)

            if meals.isEmpty {
                HStack {
                    Spacer()
                    Text("No meals logged today")
                        .font(.subheadline)
                        .foregroundColor(.gray)
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
        .background(Color(white: 0.06))
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
                        .foregroundColor(.gray)
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
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            Text(meal.dateTime.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    MealLogView(profile: UserProfile(name: "Ben", username: "ben"))
        .preferredColorScheme(.dark)
}
