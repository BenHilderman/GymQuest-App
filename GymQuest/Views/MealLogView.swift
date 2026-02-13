//
//  MealLogView.swift
//  GymQuest
//
//  Simplified food logger — text input with auto-estimated nutrition.
//

import SwiftUI
import SwiftData
import PhotosUI

struct MealLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var foodText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var suggestedTags: [String] = []
    @State private var showingCamera = false
    @State private var showLoggedOverlay = false
    @State private var editingCalories = false
    @State private var editingProtein = false
    @State private var editingCarbs = false
    @State private var editingFat = false
    @State private var manualCalories = ""
    @State private var manualProtein = ""
    @State private var manualCarbs = ""
    @State private var manualFat = ""

    private var estimation: FoodNutritionEstimator.NutritionInfo {
        FoodNutritionEstimator.estimate(from: foodText)
    }

    private var calories: Int { Int(manualCalories) ?? estimation.calories }
    private var protein: Int { Int(manualProtein) ?? estimation.protein }
    private var carbs: Int { Int(manualCarbs) ?? estimation.carbs }
    private var fat: Int { Int(manualFat) ?? estimation.fat }

    private var mealAccent: Color {
        switch guessMealType() {
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
                VStack(spacing: 24) {
                    // Text area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHAT DID YOU EAT?")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(0.5)

                        TextField("e.g., 2 eggs, toast, coffee", text: $foodText, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    // Auto-estimated nutrition row
                    if !foodText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ESTIMATED NUTRITION")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                                .tracking(0.5)

                            HStack(spacing: 8) {
                                nutritionPill(label: "Cal", value: calories, color: .orange, editing: $editingCalories, manualValue: $manualCalories)
                                nutritionPill(label: "Protein", value: protein, color: GQColors.cyanSpark, editing: $editingProtein, manualValue: $manualProtein)
                                nutritionPill(label: "Carbs", value: carbs, color: GQColors.vividPurple, editing: $editingCarbs, manualValue: $manualCarbs)
                                nutritionPill(label: "Fat", value: fat, color: GQColors.sunsetOrange, editing: $editingFat, manualValue: $manualFat)
                            }

                            Text("Tap a value to edit manually")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }

                    // Optional photo
                    if let photoData = photoData {
                        #if canImport(UIKit)
                        if let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
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
                        }
                        #endif
                    } else {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16))
                                Text("Add Photo")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Action buttons
                    VStack(spacing: 10) {
                        Button { logMeal(share: false) } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Log")
                            }
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .disabled(foodText.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button { logMeal(share: true) } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Log & Share")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [GQColors.vividPurple, GQColors.cyanSpark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .disabled(foodText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom, 120)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Log Food")
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
        suggestedTags = service.getSuggestedTags(userId: profile.id, mealType: guessMealType())
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

// MARK: - MealLogView Extensions

extension MealLogView {
    @ViewBuilder
    func nutritionPill(label: String, value: Int, color: Color, editing: Binding<Bool>, manualValue: Binding<String>) -> some View {
        Button {
            editing.wrappedValue.toggle()
        } label: {
            VStack(spacing: 4) {
                if editing.wrappedValue {
                    TextField("0", text: manualValue)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .multilineTextAlignment(.center)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 50)
                } else {
                    Text("\(value)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(GQInteractiveStyle())
    }

    func logMeal(share: Bool) {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)

        let meal = service.logMeal(
            userId: profile.id,
            mealType: guessMealType(),
            description: foodText,
            tags: [],
            photoData: photoData,
            feeling: .good,
            notes: nil
        )

        // Update nutrition estimates on the saved meal
        meal.estimatedCalories = calories
        meal.estimatedProtein = protein
        meal.estimatedCarbs = carbs
        meal.estimatedFat = fat

        if share {
            meal.privacy = .publicVisible
        }

        try? modelContext.save()
        dismiss()
    }

    private func guessMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5...10: return .breakfast
        case 11...14: return .lunch
        case 15...16: return .snack
        default: return .dinner
        }
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
            #if canImport(UIKit)
            if let photoData = meal.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                mealIconFallback
            }
            #else
            mealIconFallback
            #endif

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.mealDescription)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let cal = meal.estimatedCalories, cal > 0 {
                    Text("\(cal) cal")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                } else {
                    Text(meal.mealType.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Text(meal.dateTime.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11))
                .foregroundColor(GQColors.textTertiary)
        }
    }

    private var mealIconFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(width: 44, height: 44)

            Image(systemName: meal.mealType.icon)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    MealLogView(profile: UserProfile(name: "Ben", username: "ben"))
        .preferredColorScheme(.dark)
}
