//
//  SecondChanceOfferView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Presented when a user dismisses the main paywall. Offers an
//  extended trial to reduce churn at the paywall boundary.
//

import SwiftUI
import StoreKit

struct SecondChanceOfferView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            GQColors.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                // Emoji header
                Text("Wait!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(GQColors.textPrimary)

                Text("Special offer just for you")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(GQColors.textSecondary)

                // Offer card
                VStack(spacing: 16) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(GQGradients.primary)

                    Text("7-Day Free Trial")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(GQColors.textPrimary)

                    Text("Get full access to AI workouts, advanced analytics, and custom training plans — free for a full week.")
                        .font(.subheadline)
                        .foregroundStyle(GQColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    // Benefit bullets
                    VStack(alignment: .leading, spacing: 10) {
                        benefitRow(icon: "checkmark.circle.fill", text: "Full AI workout generation")
                        benefitRow(icon: "checkmark.circle.fill", text: "Advanced analytics & insights")
                        benefitRow(icon: "checkmark.circle.fill", text: "Cancel anytime, no commitment")
                    }
                    .padding(.top, 4)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(GQColors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(GQColors.borderDefault, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                .padding(.horizontal, 20)

                Spacer()

                // CTA
                VStack(spacing: 12) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(GQColors.error)
                    }

                    Button {
                        guard let product = subscriptionService.yearlyProduct else { return }
                        Task {
                            isPurchasing = true
                            errorMessage = nil
                            do {
                                let success = try await subscriptionService.purchase(product)
                                if success { dismiss() }
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isPurchasing = false
                        }
                    } label: {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Unlock 7-Day Trial")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isPurchasing)
                    .opacity(isPurchasing ? 0.5 : 1.0)
                    .padding(.horizontal, 20)

                    Button {
                        dismiss()
                    } label: {
                        Text("No Thanks")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(GQColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(GQColors.success)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(GQColors.textPrimary)
        }
    }
}
