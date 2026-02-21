//
//  LogView.swift
//  GymQuest
//
//  Log tab — track weight, meals, progress photos, and body measurements.
//

import SwiftUI
import SwiftData
import PhotosUI
import Charts

struct LogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    let profile: UserProfile

    @State private var showingMealLog = false
    @State private var showingAddMeasurement = false
    @State private var showingBodyMeasurements = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var todayMeals: [MealLog] = []

    private var userMeasurements: [BodyMeasurement] {
        measurements.filter { $0.userId == profile.id }
    }

    private var weightMeasurements: [BodyMeasurement] {
        userMeasurements
            .filter { $0.type == .weight }
            .sorted { $0.date < $1.date }
    }

    private var latestWeight: BodyMeasurement? {
        userMeasurements.first { $0.type == .weight }
    }

    private var latestBodyFat: BodyMeasurement? {
        userMeasurements.first { $0.type == .bodyFat }
    }

    private var latestWaist: BodyMeasurement? {
        userMeasurements.first { $0.type == .waist }
    }

    private var progressPhotos: [BodyMeasurement] {
        userMeasurements.filter { $0.photoData != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    weightSection
                    todaysMealsSection
                    progressPhotosSection
                    bodyMeasurementsSection
                    Spacer(minLength: 40)
                }
                .padding(.top, 12)
            }
            .scrollContentBackground(.hidden)
            .gqHomePageBackground()
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Log")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .onAppear { loadTodayMeals() }
            .sheet(isPresented: $showingMealLog) {
                MealLogView(profile: profile)
            }
            .sheet(isPresented: $showingAddMeasurement) {
                AddMeasurementSheet(profile: profile)
            }
            .sheet(isPresented: $showingBodyMeasurements) {
                NavigationStack {
                    BodyMeasurementsView(profile: profile)
                }
            }
            .onChange(of: showingMealLog) { _, isShowing in
                if !isShowing { loadTodayMeals() }
            }
            .onChange(of: showingAddMeasurement) { _, isShowing in
                if !isShowing { loadTodayMeals() }
            }
        }
    }

    // MARK: - Weight Section

    @ViewBuilder
    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WEIGHT")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Spacer()

                Button {
                    showingAddMeasurement = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(GQGradients.primary)
                }
            }

            HStack(spacing: 16) {
                // Current weight
                VStack(alignment: .leading, spacing: 4) {
                    if let w = latestWeight {
                        Text(String(format: "%.1f", w.value))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(GQGradients.primary)
                        + Text(" lbs")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)

                        Text(w.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    } else {
                        Text("No data")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(GQColors.textTertiary)
                        Text("Tap + to log weight")
                            .font(.system(size: 11))
                            .foregroundColor(GQColors.textTertiary)
                    }
                }

                Spacer()

                // Mini trend chart (last 7 entries)
                if weightMeasurements.count >= 2 {
                    let recent = Array(weightMeasurements.suffix(7))
                    Chart(recent, id: \.id) { m in
                        AreaMark(
                            x: .value("Date", m.date),
                            y: .value("Weight", m.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [GQColors.cyanSpark.opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", m.date),
                            y: .value("Weight", m.value)
                        )
                        .foregroundStyle(GQColors.cyanSpark.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(width: 100, height: 40)
                }
            }
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    // MARK: - Today's Meals Section

    @ViewBuilder
    private var todaysMealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S MEALS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Spacer()

                if !todayMeals.isEmpty {
                    let totalCal = todayMeals.reduce(0) { $0 + ($1.estimatedCalories ?? 0) }
                    if totalCal > 0 {
                        Text("\(totalCal) cal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
            }

            if todayMeals.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 24))
                            .foregroundColor(GQColors.textTertiary)
                        Text("No meals logged today")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                ForEach(todayMeals) { meal in
                    MealSummaryRow(meal: meal)
                }
            }

            Button {
                showingMealLog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Log Meal")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(GQColors.cyanSpark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(GQColors.cyanSpark.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(GQInteractiveStyle())
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    // MARK: - Progress Photos Section

    @ViewBuilder
    private var progressPhotosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PROGRESS PHOTOS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Spacer()

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(GQGradients.primary)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task { await saveProgressPhoto(from: newItem) }
                }
            }

            if progressPhotos.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 24))
                            .foregroundColor(GQColors.textTertiary)
                        Text("Track your transformation")
                            .font(.system(size: 13))
                            .foregroundColor(GQColors.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(progressPhotos.prefix(10)) { measurement in
                            progressPhotoTile(measurement)
                        }
                    }
                }
            }
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    #if canImport(UIKit)
    @ViewBuilder
    private func progressPhotoTile(_ measurement: BodyMeasurement) -> some View {
        if let data = measurement.photoData, let uiImage = UIImage(data: data) {
            VStack(spacing: 4) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GQGradients.glassBorder, lineWidth: 1)
                    )

                Text(measurement.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 9))
                    .foregroundColor(GQColors.textTertiary)
            }
        }
    }
    #else
    @ViewBuilder
    private func progressPhotoTile(_ measurement: BodyMeasurement) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
                .frame(width: 80, height: 100)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(GQColors.textTertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GQGradients.glassBorder, lineWidth: 1)
                )

            Text(measurement.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(size: 9))
                .foregroundColor(GQColors.textTertiary)
        }
    }
    #endif

    // MARK: - Body Measurements Section

    @ViewBuilder
    private var bodyMeasurementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BODY MEASUREMENTS")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(1)

                Spacer()

                Button {
                    showingBodyMeasurements = true
                } label: {
                    Text("See All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(GQColors.cyanSpark)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                QuickStatCard(type: .weight, measurement: latestWeight)
                QuickStatCard(type: .bodyFat, measurement: latestBodyFat)
                QuickStatCard(type: .waist, measurement: latestWaist)
            }
        }
        .padding(16)
        .homeSocialCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func loadTodayMeals() {
        let service = NutritionService.shared
        service.configure(modelContext: modelContext)
        todayMeals = service.getTodaysMeals(userId: profile.id)
    }

    private func saveProgressPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        let measurement = BodyMeasurement(
            userId: profile.id,
            type: .weight,
            value: latestWeight?.value ?? 0,
            photoData: data
        )
        modelContext.insert(measurement)
        try? modelContext.save()
    }
}

#Preview {
    LogView(profile: UserProfile(name: "Ben", username: "ben"))
        .environmentObject(AppState())
        .environmentObject(FeatureFlags.shared)
        .modelContainer(for: [BodyMeasurement.self, MealLog.self], inMemory: true)
        .preferredColorScheme(.dark)
}
