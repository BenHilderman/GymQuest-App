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
        FoodNutritionEstimator.estimate(from: foodText, weightGrams: nil)
    }

    private var calories: Int { Int(manualCalories) ?? estimation.calories }
    private var protein: Int { Int(manualProtein) ?? estimation.protein }
    private var carbs: Int { Int(manualCarbs) ?? estimation.carbs }
    private var fat: Int { Int(manualFat) ?? estimation.fat }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Input row — photo + camera
                    inputRow

                    // 2. Photo preview
                    photoPreview

                    // 3. Text field
                    foodInputSection

                    // 4. Nutrition pills
                    if !foodText.isEmpty {
                        nutritionSection
                    }

                    // 5. Log button
                    Button { logMeal() } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Log")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(foodText.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
            }
            .gqPageBackground()
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
                        HapticManager.shared.tap()
                        photoData = data
                    }
                }
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
                            .foregroundColor(GQColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(GQColors.surfaceOverlay.opacity(0.72))
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showLoggedOverlay)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var inputRow: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16))
                    Text("Photo")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(GQColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(GQColors.surfaceBase)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.borderDefault, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            #if os(iOS)
            Button {
                showingCamera = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                    Text("Camera")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(GQColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(GQColors.surfaceBase)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.borderDefault, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            #endif
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
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
                                .foregroundColor(GQColors.textPrimary)
                                .shadow(radius: 2)
                        }
                        .padding(8)
                    }
            }
            #endif
        }
    }

    @ViewBuilder
    private var foodInputSection: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField("What did you eat?", text: $foodText, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .padding()
                .background(GQColors.surfaceBase)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GQColors.borderDefault, lineWidth: 1)
                )

            if FeatureFlags.shared.voiceNotesEnabled {
                MealDictationButton(foodText: $foodText)
                    .padding(.top, 12)
            }
        }
    }

    @ViewBuilder
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                nutritionPill(label: "Cal", value: calories, color: .orange, editing: $editingCalories, manualValue: $manualCalories)
                nutritionPill(label: "Protein", value: protein, color: GQColors.cyanSpark, editing: $editingProtein, manualValue: $manualProtein)
                nutritionPill(label: "Carbs", value: carbs, color: GQColors.vividPurple, editing: $editingCarbs, manualValue: $manualCarbs)
                nutritionPill(label: "Fat", value: fat, color: GQColors.sunsetOrange, editing: $editingFat, manualValue: $manualFat)
            }

            Text("Tap a value to edit manually")
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
        }
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
                        .foregroundColor(GQColors.textPrimary)
                        .frame(width: 50)
                } else {
                    Text("\(value)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(GQColors.textPrimary)
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

    func logMeal() {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)

        if let meal = service.logMeal(
            userId: profile.id,
            mealType: guessMealType(),
            description: foodText,
            tags: [],
            photoData: photoData,
            feeling: .good,
            notes: ""
        ) {
            meal.estimatedCalories = calories
            meal.estimatedProtein = protein
            meal.estimatedCarbs = carbs
            meal.estimatedFat = fat
        }

        try? modelContext.save()
        HapticManager.shared.success()
        dismiss()
    }

    func guessMealType() -> MealType {
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
                        .foregroundColor(GQColors.textPrimary)
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
                    .foregroundColor(GQColors.textPrimary)
                    .lineLimit(1)

                if let cal = meal.estimatedCalories, cal > 0 {
                    Text("\(cal) cal")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                } else {
                    Text(meal.mealType.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.textTertiary)
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
                .fill(GQColors.surfaceBase)
                .frame(width: 44, height: 44)

            Image(systemName: meal.mealType.icon)
                .foregroundColor(GQColors.textTertiary)
        }
    }
}

// MARK: - Meal Dictation Button

struct MealDictationButton: View {
    @Binding var foodText: String
    @StateObject private var service = VoiceNoteService.shared

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button {
            if service.isTranscribing {
                service.stopLiveTranscription()
            } else {
                service.startLiveTranscription(appendTo: $foodText)
            }
        } label: {
            Image(systemName: service.isTranscribing ? "mic.fill" : "mic")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(service.isTranscribing ? .white : GQColors.cyanSpark)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(service.isTranscribing ? GQColors.coralRed : GQColors.cyanSpark.opacity(0.15))
                )
                .scaleEffect(service.isTranscribing ? pulseScale : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        pulseScale = 1.15
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MealLogView(profile: UserProfile(name: "Ben", username: "ben"))
}
