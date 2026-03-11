//
//  CoachDashboardView.swift
//  GymQuest
//
//  Dashboard for verified coaches within clubs. Shows member list,
//  recent workouts, training plan review, and note management.
//

import SwiftUI
import SwiftData

struct CoachDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    let club: Club
    let coachId: UUID

    @State private var selectedMember: ClubMembership? = nil
    @State private var showingAddNote = false
    @State private var noteText = ""
    @State private var notePriority: CoachNotePriority = .normal

    @Query private var allNotes: [CoachNote]
    @Query private var allPlans: [TrainingPlan]

    private var memberships: [ClubMembership] {
        let descriptor = FetchDescriptor<ClubMembership>()
        return (try? modelContext.fetch(descriptor))?.filter { $0.clubId == club.id } ?? []
    }

    private var coachNotes: [CoachNote] {
        allNotes.filter { $0.coachId == coachId }
    }

    var body: some View {
        List {
            // Member list
            Section("Members (\(memberships.count))") {
                ForEach(memberships, id: \.id) { membership in
                    Button {
                        selectedMember = membership
                    } label: {
                        HStack {
                            Circle()
                                .fill(GQGradients.primary)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(membership.userId.uuidString.prefix(1)))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Member \(membership.userId.uuidString.prefix(6))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(GQColors.textPrimary)

                                Text(membership.role.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundColor(GQColors.textSecondary)
                            }

                            Spacer()

                            // Note count badge
                            let noteCount = coachNotes.filter { $0.memberId == membership.userId }.count
                            if noteCount > 0 {
                                Text("\(noteCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(GQColors.deepBlue)
                                    .clipShape(Capsule())
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }
            }

            // Recent notes
            Section("Recent Notes") {
                if coachNotes.isEmpty {
                    Text("No notes yet. Select a member to add notes.")
                        .font(.subheadline)
                        .foregroundColor(GQColors.textSecondary)
                } else {
                    ForEach(coachNotes.sorted(by: { $0.createdAt > $1.createdAt }).prefix(10), id: \.id) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                priorityIcon(note.notePriority)
                                Text(note.noteText)
                                    .font(.subheadline)
                                    .foregroundColor(GQColors.textPrimary)
                                    .lineLimit(2)
                            }

                            HStack {
                                if let exercise = note.exerciseName {
                                    Text(exercise)
                                        .font(.caption2)
                                        .foregroundColor(GQColors.deepBlue)
                                }
                                Spacer()
                                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(GQColors.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Coach Dashboard")
        .sheet(item: $selectedMember) { membership in
            NavigationStack {
                MemberDetailView(
                    memberId: membership.userId,
                    coachId: coachId,
                    modelContext: modelContext
                )
            }
        }
    }

    @ViewBuilder
    private func priorityIcon(_ priority: CoachNotePriority) -> some View {
        switch priority {
        case .normal:
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundColor(GQColors.textSecondary)
        case .important:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundColor(GQColors.textSecondary)
        case .urgent:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundColor(GQColors.textSecondary)
        }
    }
}

// MARK: - Member Detail View

struct MemberDetailView: View {
    let memberId: UUID
    let coachId: UUID
    let modelContext: ModelContext

    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""
    @State private var notePriority: CoachNotePriority = .normal
    @State private var noteExercise = ""
    @State private var showingAddNote = false

    private var memberNotes: [CoachNote] {
        let descriptor = FetchDescriptor<CoachNote>()
        return (try? modelContext.fetch(descriptor))?.filter {
            $0.coachId == coachId && $0.memberId == memberId
        }.sorted(by: { $0.createdAt > $1.createdAt }) ?? []
    }

    private var memberPlans: [TrainingPlan] {
        let descriptor = FetchDescriptor<TrainingPlan>()
        return (try? modelContext.fetch(descriptor))?.filter {
            $0.userId == memberId
        }.sorted(by: { $0.createdAt > $1.createdAt }) ?? []
    }

    var body: some View {
        List {
            // Active plan
            Section("Training Plan") {
                if let plan = memberPlans.first(where: { $0.isActive }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Week \(plan.currentWeek) of \(plan.totalWeeks)")
                                .font(.caption)
                                .foregroundColor(GQColors.textSecondary)
                        }
                        Spacer()
                        Label("Reviewed", systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(GQColors.success)
                    }
                } else {
                    Text("No active plan")
                        .font(.subheadline)
                        .foregroundColor(GQColors.textSecondary)
                }
            }

            // Notes
            Section("Coach Notes") {
                ForEach(memberNotes, id: \.id) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.noteText)
                            .font(.subheadline)

                        HStack {
                            Text(note.notePriority.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundColor(GQColors.textSecondary)
                            if let exercise = note.exerciseName {
                                Text("· \(exercise)")
                                    .font(.caption2)
                                    .foregroundColor(GQColors.deepBlue)
                            }
                            Spacer()
                            Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundColor(GQColors.textSecondary)
                        }
                    }
                }

                // Add note inline
                Button {
                    showingAddNote = true
                } label: {
                    Label("Add Note", systemImage: "plus.circle.fill")
                        .foregroundColor(GQColors.deepBlue)
                }
            }
        }
        .navigationTitle("Member Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showingAddNote) {
            addNoteSheet
        }
    }

    private var addNoteSheet: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 80)
                }

                Section("Priority") {
                    Picker("Priority", selection: $notePriority) {
                        ForEach(CoachNotePriority.allCases, id: \.self) { p in
                            Text(p.rawValue.capitalized).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Exercise (Optional)") {
                    TextField("e.g. Squat", text: $noteExercise)
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddNote = false
                        noteText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                        showingAddNote = false
                    }
                    .disabled(noteText.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveNote() {
        let note = CoachNote(
            coachId: coachId,
            memberId: memberId,
            noteText: noteText,
            priority: notePriority,
            exerciseName: noteExercise.isEmpty ? nil : noteExercise
        )
        modelContext.insert(note)
        try? modelContext.save()
        noteText = ""
        noteExercise = ""
    }
}

// MARK: - ClubMembership Identifiable Conformance (for sheet)

extension ClubMembership: @retroactive Identifiable {}
