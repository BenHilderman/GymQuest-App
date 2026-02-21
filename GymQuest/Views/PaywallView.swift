//
//  PaywallView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Premium subscription paywall. Presented as a sheet when users
//  try to access gated features without an active subscription.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    featuresSection
                    tierCardsSection
                    ctaButton
                    footerSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            selectedProduct = subscriptionService.yearlyProduct
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(.systemGray3), Color(.systemGray5))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Unlock GymQuest Pro")
                .font(.title.bold())
                .foregroundStyle(.primary)

            Text("Train smarter with AI-powered workouts and advanced analytics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Features

    @ViewBuilder
    private var featuresSection: some View {
        VStack(spacing: 0) {
            featureRow(icon: "brain.head.profile", title: "AI-Generated Workouts", desc: "Personalized programs built for your goals")
            featureRow(icon: "chart.line.uptrend.xyaxis", title: "Advanced Analytics", desc: "Deep insights into volume, strength, and recovery")
            featureRow(icon: "list.bullet.clipboard", title: "Custom Training Plans", desc: "Multi-week periodized programming")
            featureRow(icon: "figure.strengthtraining.traditional", title: "Form Studio", desc: "Exercise technique library with cues")
            featureRow(icon: "clock.arrow.circlepath", title: "Unlimited History", desc: "Access your full workout archive")
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    @ViewBuilder
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Tier Cards

    @ViewBuilder
    private var tierCardsSection: some View {
        VStack(spacing: 12) {
            if let yearly = subscriptionService.yearlyProduct {
                tierCard(
                    product: yearly,
                    label: "Yearly",
                    badge: "Best Value",
                    priceDetail: "\(yearly.displayPrice)/year"
                )
            }

            if let monthly = subscriptionService.monthlyProduct {
                tierCard(
                    product: monthly,
                    label: "Monthly",
                    badge: nil,
                    priceDetail: "\(monthly.displayPrice)/month"
                )
            }
        }
    }

    @ViewBuilder
    private func tierCard(product: Product, label: String, badge: String?, priceDetail: String) -> some View {
        let isSelected = selectedProduct?.id == product.id

        Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(label)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.blue))
                        }
                    }

                    Text(priceDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.blue : Color(.systemGray3), lineWidth: 2)
                    )
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    @ViewBuilder
    private var ctaButton: some View {
        VStack(spacing: 10) {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }

            Button {
                guard let product = selectedProduct else { return }
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
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Subscribe Now")
                    }
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Capsule().fill(.blue))
            }
            .buttonStyle(.plain)
            .disabled(selectedProduct == nil || isPurchasing)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await subscriptionService.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}
