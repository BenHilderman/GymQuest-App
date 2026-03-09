//
//  Components.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Bold & Energetic reusable UI components
//  Glass morphism cards, streamlined button styles
//

import SwiftUI
import SwiftData
import MapKit
import Charts
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Card Container (Glass style)

struct CardContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.black.opacity(0.06), Color.black.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

// small colored label for status/tags
struct ChipBadge: View {
    let text: String
    let style: ChipStyle

    enum ChipStyle {
        case normal, accent, good, warn, bad // color variants
    }

    var textColor: Color {
        switch style {
        case .normal: return GQColors.textTertiary
        case .accent: return .white
        case .good: return .green
        case .warn: return .yellow
        case .bad: return .red
        }
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(textColor)
    }
}

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(GQColors.textTertiary)
            content
        }
    }
}

// MARK: - Accent Button Style (Glass style)

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(GQColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [Color.black.opacity(configuration.isPressed ? 0.05 : 0.06), Color.black.opacity(configuration.isPressed ? 0.02 : 0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.04 : 0.07), radius: configuration.isPressed ? 3 : 7, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .offset(y: configuration.isPressed ? 1.0 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

// MARK: - Animated Gradient Button Style (Subtle glass with gradient border)

struct AnimatedGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(GQColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(GQColors.surfaceBase)
            )
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.black.opacity(0.07), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 25)
                        .animatedGradientBorder(
                            cornerRadius: 25,
                            lineWidth: 1.6,
                            colors: [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
                            duration: 4.0
                        )
                }
            }
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.05 : 0.08), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .offset(y: configuration.isPressed ? 1.0 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Onboarding Button Style (Subtle glass with gradient border)

struct OnboardingButtonStyle: ButtonStyle {
    let isLastStep: Bool

    init(isLastStep: Bool = false) {
        self.isLastStep = isLastStep
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(GQColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(GQColors.surfaceBase)
            )
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.black.opacity(0.07), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 25)
                        .animatedGradientBorder(
                            cornerRadius: 25,
                            lineWidth: 1.6,
                            colors: isLastStep
                                ? [GQColors.cyanSpark, GQColors.success, GQColors.cyanSpark]
                                : [GQColors.vividPurple, GQColors.cyanSpark, GQColors.vividPurple],
                            duration: 4.0
                        )
                }
            }
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.05 : 0.08), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .offset(y: configuration.isPressed ? 1.0 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Animated Logo

struct AnimatedLogo: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(GQGradients.primary)
                .frame(width: 88, height: 88)

            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(appeared ? 1.0 : 0.8)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// MARK: - Home Section Header

struct HomeSectionHeader: View {
    let title: String
    let icon: String?
    @Binding var isExpanded: Bool

    init(title: String, icon: String? = nil, isExpanded: Binding<Bool>) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GQColors.textTertiary)
                }

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GQColors.textTertiary)
                    .tracking(0.5)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GQColors.textTertiary.opacity(0.7))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(GQColors.error)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [GQColors.error.opacity(configuration.isPressed ? 0.26 : 0.34), GQColors.error.opacity(configuration.isPressed ? 0.12 : 0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.04 : 0.07), radius: configuration.isPressed ? 3 : 7, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .offset(y: configuration.isPressed ? 1.0 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { HapticManager.shared.tap() }
            }
    }
}

struct LiftAITextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GQColors.surfaceBase)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [Color.black.opacity(0.06), Color.black.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

struct StatChip: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(GQColors.textTertiary)
        }
    }
}

// MARK: - Workout Route Map View

struct WorkoutRouteMapView: View {
    let workout: Workout

    @State private var showRoute = false

    private var coordinates: [CLLocationCoordinate2D] {
        workout.routePoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private var mapCameraPosition: MapCameraPosition {
        let coords = coordinates
        guard !coords.isEmpty else { return .automatic }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.6 + 0.005,
            longitudeDelta: (lngs.max()! - lngs.min()!) * 1.6 + 0.005
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    private var distanceString: String {
        guard let d = workout.totalDistance else { return "--" }
        return String(format: "%.2f", d / 1000.0)
    }

    private var paceString: String {
        guard let p = workout.averagePace, p > 0, p < 3600 else { return "--:--" }
        let minutes = Int(p) / 60
        let seconds = Int(p) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            let coords = coordinates

            ZStack {
                Map(initialPosition: mapCameraPosition, interactionModes: []) {
                    if showRoute {
                        MapPolyline(coordinates: coords)
                            .stroke(
                                LinearGradient(
                                    colors: [GQColors.success, GQColors.cyanSpark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 3
                            )
                    }

                    // Start marker
                    if let first = coords.first {
                        Annotation("", coordinate: first) {
                            Circle()
                                .fill(GQColors.success)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Text("S")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }

                    // Finish marker
                    if let last = coords.last {
                        Annotation("", coordinate: last) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Text("F")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .colorScheme(.dark)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Stats pills
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "map")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.success)
                    Text("\(distanceString) km")
                        .font(.system(size: 13, weight: .semibold))
                }

                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 11))
                        .foregroundColor(GQColors.cyanSpark)
                    Text("\(paceString) /km")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundColor(.white)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                showRoute = true
            }
        }
    }
}

// MARK: - Post Route Map View (compact for feed cards)

struct PostRouteMapView: View {
    let routePoints: [RoutePoint]
    var distance: String?
    var pace: String?
    var height: CGFloat = 120

    @State private var showRoute = false

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private var mapCameraPosition: MapCameraPosition {
        let coords = coordinates
        guard !coords.isEmpty else { return .automatic }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.6 + 0.005,
            longitudeDelta: (lngs.max()! - lngs.min()!) * 1.6 + 0.005
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    var body: some View {
        let coords = coordinates

        ZStack(alignment: .bottomTrailing) {
            Map(initialPosition: mapCameraPosition, interactionModes: []) {
                if showRoute {
                    MapPolyline(coordinates: coords)
                        .stroke(
                            LinearGradient(
                                colors: [GQColors.success, GQColors.cyanSpark],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 3
                        )
                }

                if let first = coords.first {
                    Annotation("", coordinate: first) {
                        Circle()
                            .fill(GQColors.success)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Text("S")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }

                if let last = coords.last {
                    Annotation("", coordinate: last) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Text("F")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .colorScheme(.dark)

            // Stats pills overlay
            if distance != nil || pace != nil {
                HStack(spacing: 8) {
                    if let distance = distance {
                        HStack(spacing: 3) {
                            Image(systemName: "map")
                                .font(.system(size: 9))
                                .foregroundColor(GQColors.success)
                            Text(distance)
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    if let pace = pace {
                        HStack(spacing: 3) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 9))
                                .foregroundColor(GQColors.cyanSpark)
                            Text(pace)
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.6)))
                .padding(8)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                showRoute = true
            }
        }
    }
}

// MARK: - Run Summary View (Strava-style)

struct RunSummaryView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss

    @State private var splits: [KilometerSplit] = []
    @State private var paceSegments: [PaceSegment] = []
    @State private var elevationProfile: [ElevationPoint] = []
    @State private var elevationGain: Double = 0
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var analyzed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroMapSection
                    statsBarSection
                    if !elevationProfile.isEmpty {
                        elevationChartSection
                    }
                    if !splits.isEmpty {
                        splitsTableSection
                    }
                    notesSection
                    Spacer(minLength: 40)
                }
                .padding(.top, 12)
            }
            .scrollContentBackground(.hidden)
            .gqPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(GQColors.cyanSpark)
                }
            }
        }
        .onAppear { analyzeRoute() }
    }

    // MARK: - Hero Map

    @ViewBuilder
    private var heroMapSection: some View {
        let coords = workout.routePoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        ZStack(alignment: .bottomLeading) {
            Map(initialPosition: cameraPosition, interactionModes: [.pan, .zoom]) {
                ForEach(paceSegments) { segment in
                    let segCoords = segment.points.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    }
                    MapPolyline(coordinates: segCoords)
                        .stroke(segment.paceCategory.color, lineWidth: 4)
                }

                // Start marker
                if let first = coords.first {
                    Annotation("", coordinate: first) {
                        Circle()
                            .fill(GQColors.success)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("S")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }

                // Finish marker
                if let last = coords.last {
                    Annotation("", coordinate: last) {
                        Circle()
                            .fill(GQColors.coralRed)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("F")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .colorScheme(.dark)

            // Pace legend
            paceLegend
                .padding(8)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .staggeredAppear(index: 0)
    }

    @ViewBuilder
    private var paceLegend: some View {
        HStack(spacing: 10) {
            legendDot(color: GQColors.success, label: "Fast")
            legendDot(color: GQColors.warning, label: "Avg")
            legendDot(color: GQColors.coralRed, label: "Slow")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // MARK: - Stats Bar

    @ViewBuilder
    private var statsBarSection: some View {
        HStack(spacing: 12) {
            WorkoutStatBadge(
                icon: "map.fill",
                value: distanceString,
                label: "km",
                color: GQColors.success
            )
            WorkoutStatBadge(
                icon: "clock.fill",
                value: durationString,
                label: "time",
                color: GQColors.cyanSpark
            )
            WorkoutStatBadge(
                icon: "speedometer",
                value: paceString,
                label: "/km",
                color: GQColors.vividPurple
            )
            WorkoutStatBadge(
                icon: "mountain.2.fill",
                value: elevationString,
                label: "m ↑",
                color: GQColors.sunsetOrange
            )
        }
        .padding(.horizontal)
        .staggeredAppear(index: 1)
    }

    // MARK: - Elevation Chart

    @ViewBuilder
    private var elevationChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ELEVATION")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)

            Chart(elevationProfile) { point in
                AreaMark(
                    x: .value("Distance", point.distanceKm),
                    y: .value("Altitude", point.altitude)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [GQColors.cyanSpark.opacity(0.4), GQColors.cyanSpark.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Distance", point.distanceKm),
                    y: .value("Altitude", point.altitude)
                )
                .foregroundStyle(GQColors.cyanSpark)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxisLabel("km", position: .trailing)
            .chartYAxisLabel("m", position: .top)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel()
                        .foregroundStyle(GQColors.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel()
                        .foregroundStyle(GQColors.textTertiary)
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
        )
        .padding(.horizontal)
        .staggeredAppear(index: 2)
    }

    // MARK: - Splits Table

    @ViewBuilder
    private var splitsTableSection: some View {
        let paces = splits.map(\.paceSecondsPerKm)
        let fastest = paces.min() ?? 1
        let slowest = paces.max() ?? 1
        let range = slowest - fastest

        VStack(alignment: .leading, spacing: 12) {
            Text("SPLITS")
                .font(GQTypography.sectionHeader)
                .foregroundColor(GQColors.sectionLabel)
                .tracking(1)

            // Header
            HStack {
                Text("KM")
                    .frame(width: 32, alignment: .leading)
                Text("PACE")
                    .frame(width: 52, alignment: .leading)
                Text("ELEV")
                    .frame(width: 44, alignment: .trailing)
                Spacer()
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(GQColors.textTertiary)

            ForEach(splits) { split in
                splitRow(split: split, fastest: fastest, range: range)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GQColors.surfaceBase)
        )
        .padding(.horizontal)
        .staggeredAppear(index: 3)
    }

    @ViewBuilder
    private func splitRow(split: KilometerSplit, fastest: Double, range: Double) -> some View {
        let normalized = range > 0 ? 1.0 - ((split.paceSecondsPerKm - fastest) / range) : 0.5
        let barColor: Color = normalized > 0.66 ? GQColors.success : (normalized > 0.33 ? GQColors.warning : GQColors.coralRed)
        let barWidth = max(20.0, normalized * 80.0)

        HStack {
            Text("\(split.id)")
                .frame(width: 32, alignment: .leading)
                .foregroundColor(GQColors.textPrimary)

            Text(split.paceString)
                .frame(width: 52, alignment: .leading)
                .monospacedDigit()
                .foregroundColor(GQColors.textPrimary)

            Text(elevChangeString(split.elevationChange))
                .frame(width: 44, alignment: .trailing)
                .foregroundColor(split.elevationChange >= 0 ? GQColors.success : GQColors.coralRed)

            Spacer()

            RoundedRectangle(cornerRadius: 3)
                .fill(barColor)
                .frame(width: barWidth, height: 12)
        }
        .font(.system(size: 13, weight: .medium))
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        if !workout.notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("NOTES")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.sectionLabel)
                    .tracking(1)

                Text(workout.notes)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .staggeredAppear(index: 4)
        }
    }

    // MARK: - Helpers

    private var distanceString: String {
        guard let d = workout.totalDistance else { return "--" }
        return String(format: "%.2f", d / 1000.0)
    }

    private var durationString: String {
        let mins = workout.duration
        if mins >= 60 {
            return "\(mins / 60)h\(String(format: "%02d", mins % 60))"
        }
        return "\(mins)m"
    }

    private var paceString: String {
        guard let p = workout.averagePace, p > 0, p < 3600 else { return "--:--" }
        let minutes = Int(p) / 60
        let seconds = Int(p) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    private var elevationString: String {
        let gain = elevationGain
        if gain > 0 { return String(format: "%.0f", gain) }
        return "--"
    }

    private func elevChangeString(_ change: Double) -> String {
        let arrow = change >= 0 ? "↑" : "↓"
        return "\(arrow)\(String(format: "%.0f", abs(change)))"
    }

    private func analyzeRoute() {
        guard !analyzed else { return }
        analyzed = true

        let points = workout.routePoints
        guard !points.isEmpty else { return }

        splits = RunAnalysis.computeSplits(from: points)
        paceSegments = RunAnalysis.computePaceSegments(
            from: points,
            averagePace: workout.averagePace ?? 0
        )
        elevationProfile = RunAnalysis.computeElevationProfile(from: points)
        elevationGain = workout.elevationGain ?? RunAnalysis.computeElevationGain(from: points)

        // Compute map camera
        let coords = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        if let minLat = lats.min(), let maxLat = lats.max(),
           let minLng = lngs.min(), let maxLng = lngs.max() {
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.4 + 0.005,
                longitudeDelta: (maxLng - minLng) * 1.4 + 0.005
            )
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: Workout

    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.type.rawValue)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(session.date.formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(GQColors.textTertiary)
                    }

                    // stats row
                    HStack(spacing: 32) {
                        StatChip(value: "\(session.duration)", label: "min")
                        StatChip(value: "\(session.totalSets)", label: "sets")
                        StatChip(value: "\(session.exercises.count)", label: "exercises")
                    }

                    // Distance/pace stats for GPS workouts
                    if session.hasRoute {
                        HStack(spacing: 32) {
                            if let dist = session.totalDistance {
                                StatChip(value: String(format: "%.2f", dist / 1000.0), label: "km")
                            }
                            if let pace = session.averagePace, pace > 0, pace < 3600 {
                                let min = Int(pace) / 60
                                let sec = Int(pace) % 60
                                StatChip(value: String(format: "%d:%02d", min, sec), label: "/km")
                            }
                        }
                    }

                    // Route map for GPS workouts
                    if session.hasRoute {
                        WorkoutRouteMapView(workout: session)
                    }

                    // exercises
                    if !session.exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exercises")
                                .font(.headline)

                            ForEach(session.exercises.sorted(by: { $0.order < $1.order })) { exercise in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(exercise.name)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(exercise.muscleGroup.rawValue)
                                            .font(.caption)
                                            .foregroundColor(GQColors.textTertiary)
                                    }

                                    ForEach(exercise.sets.sorted(by: { $0.order < $1.order })) { set in
                                        HStack {
                                            Text("\(set.reps) reps")
                                                .font(.subheadline)
                                            if set.weight > 0 {
                                                Text("× \(Int(set.weight)) lbs")
                                                    .font(.subheadline)
                                                    .foregroundColor(GQColors.textTertiary)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.black.opacity(0.03))
                                .cornerRadius(12)
                            }
                        }
                    }

                    // notes
                    if !session.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(session.notes)
                                .foregroundColor(GQColors.textTertiary)
                        }
                    }

                    Spacer().frame(height: 20)

                    Button("Delete Workout") {
                        showingDeleteAlert = true
                    }
                    .buttonStyle(DangerButtonStyle())
                }
                .padding()
            }
            .gqPageBackground()
            .navigationTitle("Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Workout", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    modelContext.delete(session)
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
    }
}

struct WorkoutCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let workout: Workout
    let xpEarned: Int
    let leveledUp: Bool
    let newLevel: Int
    let profile: UserProfile
    var photoData: Data? = nil
    var caption: String = ""

    @State private var prMoments: [PRMoment] = []
    @State private var prEvents: [PREvent] = []
    @State private var coachTakeaway: String?
    @State private var workoutSummary: WorkoutSummary?
    @State private var isLoading = true
    @State private var showConfetti = false
    @State private var cardAppeared = false
    @State private var showShareSheet = false
    @State private var showPRCelebration = false
    @State private var selectedPRForShare: PRMoment?
    #if canImport(UIKit)
    @State private var cardImage: UIImage?
    #endif
    @State private var selectedVisibility: CardVisibility = .pod

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // level up celebration
                    if leveledUp {
                        LevelUpBanner(newLevel: newLevel)
                    }

                    // PR celebration banner with quick share CTA
                    if !prMoments.isEmpty && !isLoading {
                        PRCelebrationBanner(
                            prMoments: prMoments,
                            onSharePR: { pr in
                                selectedPRForShare = pr
                                showPRCelebration = true
                            }
                        )
                    }

                    // the workout card
                    if isLoading {
                        CardLoadingPlaceholder()
                    } else {
                        WorkoutCardView(
                            workout: workout,
                            profile: profile,
                            streakCount: workoutSummary?.streak ?? 0,
                            xpEarned: xpEarned,
                            prMoments: prMoments,
                            coachTakeaway: coachTakeaway,
                            fistBumpCount: 0
                        )
                        .scaleEffect(cardAppeared ? 1.0 : 0.85)
                        .opacity(cardAppeared ? 1.0 : 0)
                    }

                    // Quick stats summary
                    if let summary = workoutSummary {
                        QuickStatsSummary(summary: summary)
                    }

                    // share options
                    VStack(spacing: 16) {
                        Text("SHARE YOUR WORKOUT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(GQColors.textTertiary)
                            .tracking(1)

                        // visibility picker
                        HStack(spacing: 12) {
                            ShareOptionButton(
                                title: "Pod",
                                icon: "person.3.fill",
                                isSelected: selectedVisibility == .pod
                            ) {
                                selectedVisibility = .pod
                            }

                            ShareOptionButton(
                                title: "Friends",
                                icon: "person.2.fill",
                                isSelected: selectedVisibility == .friends
                            ) {
                                selectedVisibility = .friends
                            }

                            ShareOptionButton(
                                title: "Export",
                                icon: "square.and.arrow.up",
                                isSelected: false
                            ) {
                                exportCard()
                            }
                        }

                        // Primary share button
                        Button {
                            shareToFeed()
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Share to \(selectedVisibility.rawValue)")
                            }
                        }
                        .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.cyanSpark))

                        // Keep Private button (secondary action)
                        Button {
                            dismiss()
                        } label: {
                            Text("Keep Private")
                        }
                        .buttonStyle(HomeSocialSecondaryButtonStyle(cornerRadius: 12))
                        .padding(.top, 4)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .gqPageBackground()
            .navigationTitle("Workout Complete")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                await generateCardContent()
            }
            .overlay {
                if showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                }
            }
            .onChange(of: isLoading) { _, newValue in
                if !newValue {
                    HapticManager.shared.workoutComplete()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        cardAppeared = true
                    }
                    showConfetti = true
                }
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showShareSheet) {
                if let image = cardImage {
                    ShareSheet(items: [image])
                }
            }
            .sheet(isPresented: $showPRCelebration) {
                if let pr = selectedPRForShare {
                    PRShareSheet(prMoment: pr, workout: workout, profile: profile)
                }
            }
            #endif
        }
    }

    // generates the workout card content (PRs, streak, coach insight)
    @MainActor
    private func generateCardContent() async {
        let aiService = AIService()
        let prService = PRService.shared
        let analytics = AnalyticsService.shared
        analytics.configure(modelContext: modelContext)

        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let allWorkouts = (try? modelContext.fetch(descriptor)) ?? []

        // Use enhanced PR detection
        let prResults = prService.detectAllPRs(
            workout: workout,
            allWorkouts: allWorkouts,
            profile: profile,
            modelContext: modelContext
        )
        prEvents = prResults.events
        prMoments = prResults.moments

        // Track PRs
        for pr in prMoments {
            analytics.trackPRDetected(
                userId: profile.id,
                prType: pr.prType.rawValue,
                exerciseName: pr.exerciseName,
                improvement: pr.improvement
            )
        }

        // Generate workout summary
        workoutSummary = prService.generateWorkoutSummary(
            workout: workout,
            profile: profile,
            allWorkouts: allWorkouts
        )

        // AI generates a short takeaway for the card
        coachTakeaway = await aiService.generateCoachTakeaway(
            workout: workout,
            profile: profile,
            workouts: allWorkouts,
            hasPR: !prMoments.isEmpty
        )

        // Track workout completion
        analytics.trackWorkoutCompleted(
            userId: profile.id,
            duration: workout.duration,
            totalSets: workout.totalSets,
            xpEarned: xpEarned
        )

        try? modelContext.save()
        isLoading = false
    }

    // saves workout card + post to feed
    private func shareToFeed() {
        let analytics = AnalyticsService.shared

        // build exercise summary for the card
        let exerciseSummary = workout.exercises.map { exercise -> ExerciseSummaryItem in
            let sets = exercise.sets.sorted { $0.order < $1.order }
            let avgReps = sets.isEmpty ? 0 : sets.map { $0.reps }.reduce(0, +) / sets.count
            let maxWeight = sets.map { $0.weight }.max() ?? 0
            return ExerciseSummaryItem(
                name: exercise.name,
                sets: sets.count,
                reps: "\(avgReps)",
                weight: maxWeight
            )
        }

        let summaryJSON = (try? JSONEncoder().encode(exerciseSummary))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let card = WorkoutCard(
            odId: profile.id,
            odName: profile.name,
            odUsername: profile.username,
            workoutId: workout.id,
            workoutType: workout.type.rawValue,
            duration: workout.duration,
            totalSets: workout.totalSets,
            avgRPE: Double(workout.rpe),
            exerciseSummary: summaryJSON,
            coachTakeaway: coachTakeaway,
            xpEarned: xpEarned,
            streakCount: workoutSummary?.streak ?? 0,
            visibility: selectedVisibility
        )

        modelContext.insert(card)

        // also create a post for the feed
        let post = Post(
            id: UUID(),
            authorId: profile.id,
            authorName: profile.name,
            authorUsername: profile.username,
            caption: caption.isEmpty ? (coachTakeaway ?? "") : caption,
            photoData: photoData,
            workoutType: workout.type.rawValue,
            duration: workout.duration,
            setCount: workout.totalSets
        )
        modelContext.insert(post)

        // Track card creation
        analytics.trackWorkoutCardCreated(
            userId: profile.id,
            hasPRs: !prMoments.isEmpty,
            hasCoachTakeaway: coachTakeaway != nil
        )

        do {
            try modelContext.save()
        } catch {
            print("Failed to save post to feed: \(error)")
        }
        dismiss()
    }

    #if canImport(UIKit)
    private func exportCard() {
        guard let summary = workoutSummary else { return }

        let shareService = ShareService.shared
        let analytics = AnalyticsService.shared

        if let image = shareService.exportWorkoutCard(
            workout: workout,
            profile: profile,
            summary: summary,
            prMoments: prMoments,
            coachTakeaway: coachTakeaway
        ) {
            cardImage = image
            showShareSheet = true
            analytics.trackShareExported(userId: profile.id, shareType: "workout_card")
        }
    }
    #else
    private func exportCard() {
        // macOS export not implemented
    }
    #endif
}

// MARK: - PR Celebration Banner

struct PRCelebrationBanner: View {
    let prMoments: [PRMoment]
    let onSharePR: (PRMoment) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEW PR\(prMoments.count > 1 ? "s" : "")!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)

                    Text("You hit \(prMoments.count) personal record\(prMoments.count > 1 ? "s" : "") today")
                        .font(.system(size: 13))
                        .foregroundColor(GQColors.textSecondary)
                }

                Spacer()
            }

            // Quick share buttons for each PR
            ForEach(prMoments.prefix(2)) { pr in
                Button {
                    onSharePR(pr)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let exercise = pr.exerciseName {
                                Text(exercise)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(GQColors.textPrimary)
                            }
                            Text(pr.value)
                                .font(.system(size: 13))
                                .foregroundColor(GQColors.textSecondary)
                        }

                        Spacer()

                        Text("Share")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.03))
                    .cornerRadius(10)
                }
                .buttonStyle(GQInteractiveStyle())
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [GQColors.cyanSpark.opacity(0.15), GQColors.vividPurple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(GQColors.cyanSpark.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Quick Stats Summary

struct QuickStatsSummary: View {
    let summary: WorkoutSummary

    var body: some View {
        HStack(spacing: 0) {
            QuickStat(value: "\(summary.totalSets)", label: "sets")
            Divider().frame(height: 30).background(Color.black.opacity(0.06))
            QuickStat(value: summary.formattedVolume, label: "volume")
            Divider().frame(height: 30).background(Color.black.opacity(0.06))
            QuickStat(value: "\(summary.duration)", label: "min")
            if summary.streak >= 3 {
                Divider().frame(height: 30).background(Color.black.opacity(0.06))
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(GQColors.success)
                    Text("\(summary.streak)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(GQColors.success)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.03))
        .cornerRadius(12)
    }
}

struct QuickStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(GQColors.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(GQColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PR Share Sheet

#if canImport(UIKit)
struct PRShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let prMoment: PRMoment
    let workout: Workout
    let profile: UserProfile

    @State private var showShareSheet = false
    @State private var cardImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview of PR card
                ShareablePRCard(
                    prMoment: prMoment,
                    workout: workout,
                    profile: profile
                )
                .scaleEffect(0.85)
                .frame(height: 400)

                Spacer()

                // Export button
                Button {
                    exportPRCard()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export PR Card")
                    }
                }
                .buttonStyle(HomeSocialPrimaryButtonStyle(accent: GQColors.cyanSpark))
                .padding(.horizontal, 24)

                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(GQColors.textTertiary)
                .padding(.bottom, 32)
            }
            .gqPageBackground()
            .navigationTitle("Share Your PR")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showShareSheet) {
                if let image = cardImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    private func exportPRCard() {
        let shareService = ShareService.shared

        if let image = shareService.exportPRCard(
            prMoment: prMoment,
            workout: workout,
            profile: profile
        ) {
            cardImage = image
            showShareSheet = true
        }
    }
}
#endif

struct LevelUpBanner: View {
    let newLevel: Int
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(GQColors.cyanSpark.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(GQColors.cyanSpark)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("LEVEL UP!")
                    .font(GQTypography.sectionHeader)
                    .foregroundColor(GQColors.cyanSpark)
                    .tracking(1)

                Text("Level \(newLevel) - \(UserProfile.levelTitle(for: newLevel))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GQColors.textPrimary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [GQColors.cyanSpark.opacity(0.15), GQColors.sunsetOrange.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQColors.cyanSpark.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: GQColors.cyanSpark.opacity(0.06), radius: 12, y: 4)
    }
}

struct CardLoadingPlaceholder: View {
    @State private var pulseOpacity: Double = 0.3

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(GQColors.vividPurple)

            Text("Generating your workout card...")
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.03))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(GQColors.vividPurple.opacity(pulseOpacity), lineWidth: 1)
        )
        .shimmer()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.6
            }
        }
    }
}

struct ShareOptionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? GQColors.textPrimary : GQColors.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? GQColors.surfaceElevated : GQColors.surfaceBase)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? GQColors.vividPurple.opacity(0.5) : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? GQColors.vividPurple.opacity(0.06) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(GQInteractiveStyle())
    }
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(GQColors.textTertiary)
        }
    }
}

#Preview {
    CardContainer {
        Text("Preview")
    }
    .padding()
}
