//
//  TrainingPlanView.swift
//  GymQuest
//
//  AI-generated training plan management. Displays active plan with week/day breakdown,
//  allows generating new plans, and launches workouts from plan days.
//

import SwiftUI
import SwiftData

struct TrainingPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query(sort: \TrainingPlan.createdAt, order: .reverse) private var plans: [TrainingPlan]
    let profile: UserProfile

    @State private var showingGenerateSheet = false
    @State private var selectedWeeks = 4
    @State private var isGenerating = false

    private var activePlan: TrainingPlan? {
        plans.first { $0.isActive }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let plan = activePlan {
                    activePlanCard(plan)
                } else {
                    noPlanCard
                }

                if plans.count > 1 {
                    pastPlansSection
                }
            }
            .padding()
        }
        .navigationTitle("Training Plan")
        .sheet(isPresented: $showingGenerateSheet) {
            generatePlanSheet
        }
    }

    // MARK: - Active Plan Card

    @ViewBuilder
    private func activePlanCard(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(GQColors.textPrimary)
                    Text("Week \(plan.currentWeek) of \(plan.totalWeeks)")
                        .font(.subheadline)
                        .foregroundColor(GQColors.textSecondary)
                }
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(GQGradients.primary)
            }

            // Week tabs
            if !plan.weeks.isEmpty {
                let currentWeekData = plan.weeks[min(plan.currentWeek - 1, plan.weeks.count - 1)]

                VStack(alignment: .leading, spacing: 8) {
                    Text(currentWeekData.focus.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(GQColors.vividPurple)

                    ForEach(currentWeekData.days) { day in
                        dayRow(day, plan: plan)
                    }
                }
            }
        }
        .padding()
        .background(GQColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func dayRow(_ day: TrainingPlanDay, plan: TrainingPlan) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(day.dayNumber): \(day.label)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(day.isRestDay ? GQColors.textSecondary : GQColors.textPrimary)

                if !day.isRestDay {
                    Text("\(day.exercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(GQColors.textSecondary)
                }
            }

            Spacer()

            if day.isRestDay {
                Image(systemName: "moon.fill")
                    .foregroundColor(GQColors.textSecondary)
            } else {
                Button {
                    startWorkoutFromPlan(day: day, plan: plan)
                } label: {
                    Text("Start")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(GQGradients.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - No Plan Card

    private var noPlanCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(GQGradients.primary)

            Text("No Active Training Plan")
                .font(.headline)
                .foregroundColor(GQColors.textPrimary)

            Text("Generate an AI-powered plan tailored to your goals, experience, and schedule.")
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingGenerateSheet = true
            } label: {
                Text("Generate Plan")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(GQGradients.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(GQColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Past Plans

    private var pastPlansSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Past Plans")
                .font(.headline)
                .foregroundColor(GQColors.textPrimary)

            ForEach(plans.filter { !$0.isActive }) { plan in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title)
                            .font(.subheadline)
                            .foregroundColor(GQColors.textPrimary)
                        Text(plan.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(GQColors.textSecondary)
                    }
                    Spacer()
                    if plan.completedAt != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(GQColors.success)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Generate Sheet

    private var generatePlanSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("AI Training Plan")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan Duration")
                        .font(.subheadline)
                        .foregroundColor(GQColors.textSecondary)

                    Picker("Weeks", selection: $selectedWeeks) {
                        Text("4 Weeks").tag(4)
                        Text("6 Weeks").tag(6)
                        Text("8 Weeks").tag(8)
                        Text("12 Weeks").tag(12)
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Goal: \(profile.goal.rawValue)", systemImage: "target")
                    Label("\(profile.daysPerWeek) days/week", systemImage: "calendar")
                    Label("Experience: \(profile.experienceLevel?.rawValue ?? "Intermediate")", systemImage: "chart.bar.fill")
                }
                .font(.subheadline)
                .foregroundColor(GQColors.textSecondary)

                Spacer()

                Button {
                    generatePlan()
                } label: {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Generate Plan")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isGenerating ? Color.gray : GQColors.vividPurple)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isGenerating)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingGenerateSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func generatePlan() {
        isGenerating = true
        Task {
            let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let workouts = (try? modelContext.fetch(descriptor)) ?? []

            // Deactivate existing active plan
            if let existing = activePlan {
                existing.isActive = false
                existing.completedAt = Date()
            }

            _ = try? await TrainingPlanService.shared.generatePlan(
                profile: profile,
                workouts: workouts,
                weeks: selectedWeeks,
                modelContext: modelContext
            )

            isGenerating = false
            showingGenerateSheet = false
        }
    }

    private func startWorkoutFromPlan(day: TrainingPlanDay, plan: TrainingPlan) {
        let activeExercises = TrainingPlanService.shared.planDayToActiveExercises(day)
        let workoutType = WorkoutType(rawValue: day.workoutType) ?? .custom
        appState.startWorkout(type: workoutType, exercises: activeExercises)

        // Advance day in plan
        if plan.currentDay < (plan.weeks[plan.currentWeek - 1].days.count) {
            plan.currentDay += 1
        } else if plan.currentWeek < plan.totalWeeks {
            plan.currentWeek += 1
            plan.currentDay = 1
        }
        try? modelContext.save()
    }
}
