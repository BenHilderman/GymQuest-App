import SwiftUI
#if canImport(Speech)
import Speech
#endif

/// Structured + free-text search with voice input.
struct SmartSearchBar: View {
    @Binding var query: String
    @Binding var bodyPart: String?
    @Binding var durationCap: Int?      // minutes
    @Binding var equipment: String?

    /// When false (default), the filter chips collapse and the bar is a
    /// single tidy row. ExploreView flips this on once a search is active so
    /// the chips appear contextually instead of cluttering the header.
    var showsChips: Bool = true
    var onSubmit: () -> Void = {}

    #if canImport(Speech) && canImport(AVFoundation)
    @StateObject private var voice = VoiceSearchService()
    #endif

    private let bodyParts = ["Push", "Pull", "Legs", "Cardio", "Core", "Full body"]
    private let durations = [15, 30, 45, 60, 90]
    private let equipmentOptions = ["Bodyweight", "Dumbbells", "Barbell", "Machines", "Kettlebell"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(GQColors.textTertiary)
                    .font(.system(size: 13, weight: .semibold))

                TextField("Search workouts, exercises, athletes…", text: $query)
                    .font(.system(size: 14))
                    .foregroundColor(GQColors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit(onSubmit)

                if hasAnyFilter {
                    Button { clearAll() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(GQColors.textTertiary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }

                micButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Capsule().fill(GQColors.surfaceSecondary))
            .overlay(Capsule().stroke(GQColors.borderDefault, lineWidth: 0.5))

            voiceErrorBanner

            if showsChips || hasActiveChip {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chipMenu(label: "Body part", value: bodyPart, options: bodyParts) { bodyPart = $0 }
                        chipMenu(label: "Duration", value: durationCap.map { "\($0) min" }, options: durations.map { "\($0) min" }) { sel in
                            durationCap = sel.map { Int($0.replacingOccurrences(of: " min", with: "")) ?? 0 }
                        }
                        chipMenu(label: "Equipment", value: equipment, options: equipmentOptions) { equipment = $0 }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsChips || hasActiveChip)
    }

    private var hasActiveChip: Bool {
        bodyPart != nil || durationCap != nil || equipment != nil
    }

    // MARK: - Chip menu

    @ViewBuilder
    private func chipMenu(
        label: String,
        value: String?,
        options: [String],
        onSelect: @escaping (String?) -> Void
    ) -> some View {
        Menu {
            Button("Any") { onSelect(nil) }
            ForEach(options, id: \.self) { opt in
                Button(opt) { onSelect(opt) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(value ?? label)
                    .font(.system(size: 12, weight: value == nil ? .medium : .semibold))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(value == nil ? GQColors.textSecondary : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(value == nil ? GQColors.surfaceSecondary : GQColors.accent)
            )
            .overlay(Capsule().stroke(GQColors.borderDefault, lineWidth: 0.5))
        }
    }

    private var hasAnyFilter: Bool {
        !query.isEmpty || bodyPart != nil || durationCap != nil || equipment != nil
    }

    private func clearAll() {
        query = ""
        bodyPart = nil
        durationCap = nil
        equipment = nil
    }

    // MARK: - Voice search

    @ViewBuilder
    private var micButton: some View {
        #if os(iOS) && canImport(Speech) && canImport(AVFoundation)
        let isListening = voice.state == .listening
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            if isListening {
                voice.stop()
            } else {
                voice.start { partial in query = partial }
            }
        } label: {
            Image(systemName: isListening ? "mic.fill" : "mic")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isListening ? .white : GQColors.textTertiary)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(isListening ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(Color.clear))
                )
                .scaleEffect(isListening ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.25), value: isListening)
        }
        .buttonStyle(.plain)
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var voiceErrorBanner: some View {
        #if os(iOS) && canImport(Speech) && canImport(AVFoundation)
        if case .error(let message) = voice.state {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                Text(message).font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.orange.opacity(0.12)))
        }
        #else
        EmptyView()
        #endif
    }
}
