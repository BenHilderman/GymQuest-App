//
//  BodyMeasurementsView.swift
//  GymQuest
//
//  Track body measurements over time.
//

import SwiftUI
import SwiftData
import Charts

struct BodyMeasurementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    let profile: UserProfile

    @State private var showingAddMeasurement = false
    @State private var selectedType: MeasurementType = .weight

    var userMeasurements: [BodyMeasurement] {
        measurements.filter { $0.userId == profile.id }
    }

    var latestMeasurements: [MeasurementType: BodyMeasurement] {
        var latest: [MeasurementType: BodyMeasurement] = [:]
        for measurement in userMeasurements {
            if latest[measurement.type] == nil {
                latest[measurement.type] = measurement
            }
        }
        return latest
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach([MeasurementType.weight, .bodyFat, .waist], id: \.self) { type in
                        QuickStatCard(
                            type: type,
                            measurement: latestMeasurements[type]
                        )
                        .onTapGesture {
                            selectedType = type
                        }
                    }
                }
                .padding(.horizontal)

                // Chart for selected type
                if !measurementsForType(selectedType).isEmpty {
                    MeasurementChartCard(
                        type: selectedType,
                        measurements: measurementsForType(selectedType)
                    )
                    .padding(.horizontal)
                }

                // All measurements by type
                VStack(alignment: .leading, spacing: 16) {
                    Text("ALL MEASUREMENTS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(0.5)
                        .padding(.horizontal)

                    ForEach(MeasurementType.allCases, id: \.self) { type in
                        MeasurementTypeRow(
                            type: type,
                            latest: latestMeasurements[type],
                            trend: calculateTrend(for: type)
                        )
                        .onTapGesture {
                            selectedType = type
                        }
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .background(EnergyBackground())
        .navigationTitle("Body Measurements")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddMeasurement = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(GQGradients.primary)
                }
            }
        }
        .sheet(isPresented: $showingAddMeasurement) {
            AddMeasurementSheet(profile: profile)
        }
    }

    private func measurementsForType(_ type: MeasurementType) -> [BodyMeasurement] {
        userMeasurements
            .filter { $0.type == type }
            .sorted { $0.date < $1.date }
    }

    private func calculateTrend(for type: MeasurementType) -> Double? {
        let typeData = measurementsForType(type)
        guard typeData.count >= 2 else { return nil }

        let recent = typeData.suffix(2)
        if let first = recent.first, let last = recent.last {
            return last.value - first.value
        }
        return nil
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let type: MeasurementType
    let measurement: BodyMeasurement?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(GQColors.cyanSpark)

            if let m = measurement {
                Text(String(format: "%.1f", m.value))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(type.unit)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            } else {
                Text("--")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gray)
            }

            Text(type.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Measurement Chart

struct MeasurementChartCard: View {
    let type: MeasurementType
    let measurements: [BodyMeasurement]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(type.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if let first = measurements.first, let last = measurements.last, measurements.count > 1 {
                    let diff = last.value - first.value
                    HStack(spacing: 4) {
                        Image(systemName: diff >= 0 ? "arrow.up" : "arrow.down")
                        Text(String(format: "%.1f %@", abs(diff), type.unit))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(diff >= 0 ? GQColors.success : GQColors.error)
                }
            }

            Chart(measurements) { m in
                LineMark(
                    x: .value("Date", m.date),
                    y: .value("Value", m.value)
                )
                .foregroundStyle(GQColors.cyanSpark.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Date", m.date),
                    y: .value("Value", m.value)
                )
                .foregroundStyle(GQColors.cyanSpark)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .foregroundStyle(.gray)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(.gray)
                }
            }
            .frame(height: 180)
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

// MARK: - Measurement Type Row

struct MeasurementTypeRow: View {
    let type: MeasurementType
    let latest: BodyMeasurement?
    let trend: Double?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(GQColors.vividPurple.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(GQColors.vividPurple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                if let m = latest {
                    Text(m.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                } else {
                    Text("No data")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            if let m = latest {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f %@", m.value, type.unit))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    if let t = trend {
                        HStack(spacing: 2) {
                            Image(systemName: t >= 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 9))
                            Text(String(format: "%.1f", abs(t)))
                                .font(.system(size: 10))
                        }
                        .foregroundColor(t >= 0 ? GQColors.success : GQColors.error)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
    }
}

// MARK: - Add Measurement Sheet

struct AddMeasurementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var selectedType: MeasurementType = .weight
    @State private var value: String = ""
    @State private var date: Date = Date()
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurement Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(MeasurementType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("Value") {
                    HStack {
                        TextField("0.0", text: $value)
                            .keyboardType(.decimalPad)

                        Text(selectedType.unit)
                            .foregroundColor(.gray)
                    }
                }

                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Notes (Optional)") {
                    TextField("Any notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Add Measurement")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMeasurement()
                    }
                    .disabled(value.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveMeasurement() {
        guard let numValue = Double(value) else { return }

        let measurement = BodyMeasurement(
            userId: profile.id,
            type: selectedType,
            value: numValue,
            date: date,
            notes: notes.isEmpty ? nil : notes
        )

        modelContext.insert(measurement)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        BodyMeasurementsView(profile: UserProfile(name: "Ben", username: "ben"))
    }
    .preferredColorScheme(.dark)
}
