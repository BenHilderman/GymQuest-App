//
//  PaywallView.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  Premium subscription paywall with social proof, trial timeline,
//  price anchoring, and second-chance offer on dismiss.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showSecondChanceOffer = false
    @State private var hasShownSecondChance = false

    var body: some View {
        ZStack {
            GQColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    socialProofSection
                    featuresSection
                    trialTimelineSection
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
            Button {
                if hasShownSecondChance {
                    dismiss()
                } else {
                    hasShownSecondChance = true
                    showSecondChanceOffer = true
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(GQColors.textTertiary, GQColors.surfaceElevated)
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .sheet(isPresented: $showSecondChanceOffer, onDismiss: {
            dismiss()
        }) {
            SecondChanceOfferView()
                .environmentObject(subscriptionService)
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: 14) {
            NavBarLogo()

            Text("Train smarter with AI-powered workouts and advanced analytics.")
                .font(.subheadline)
                .foregroundStyle(GQColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Social Proof

    @ViewBuilder
    private var socialProofSection: some View {
        VStack(spacing: 6) {
            // Star rating
            HStack(spacing: 3) {
                ForEach(0..<5) { i in
                    Image(systemName: i < 4 ? "star.fill" : "star.leadinghalf.filled")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                }
                Text("4.8")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(GQColors.textPrimary)
                Text("(2,400+ reviews)")
                    .font(.system(size: 13))
                    .foregroundStyle(GQColors.textSecondary)
            }

            Text("Join 50,000+ lifters training smarter")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(GQColors.textSecondary)
        }
    }

    // MARK: - Features

    @ViewBuilder
    private var featuresSection: some View {
        VStack(spacing: 0) {
            featureRow(icon: "brain.head.profile", title: "AI-Generated Workouts", desc: "Personalized programs built for your goals", color: GQColors.deepBlue)
            featureRow(icon: "chart.line.uptrend.xyaxis", title: "Advanced Analytics", desc: "Deep insights into volume, strength, and recovery", color: GQColors.deepBlue)
            featureRow(icon: "list.bullet.clipboard", title: "Custom Training Plans", desc: "Multi-week periodized programming", color: GQColors.textSecondary)
            featureRow(icon: "figure.strengthtraining.traditional", title: "Form Studio", desc: "Exercise technique library with cues", color: GQColors.success)
            featureRow(icon: "clock.arrow.circlepath", title: "Unlimited History", desc: "Access your full workout archive", color: GQColors.deepBlue)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GQColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    @ViewBuilder
    private func featureRow(icon: String, title: String, desc: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GQColors.textPrimary)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(GQColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Trial Timeline

    @ViewBuilder
    private var trialTimelineSection: some View {
        VStack(spacing: 16) {
            Text("HOW YOUR FREE TRIAL WORKS")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(GQColors.textTertiary)
                .tracking(1)

            HStack(spacing: 0) {
                timelineStep(
                    icon: "lock.open.fill",
                    day: "Today",
                    desc: "Full Access",
                    isFirst: true
                )

                timelineConnector

                timelineStep(
                    icon: "bell.fill",
                    day: "Day 2",
                    desc: "Reminder",
                    isFirst: false
                )

                timelineConnector

                timelineStep(
                    icon: "creditcard.fill",
                    day: "Day 3",
                    desc: "Billing Starts",
                    isFirst: false
                )
            }
            .padding(.horizontal, 8)

            Text("No Payment Due Now")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(GQColors.success)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GQColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GQColors.borderDefault, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func timelineStep(icon: String, day: String, desc: String, isFirst: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isFirst ? GQColors.success : GQColors.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isFirst ? GQColors.success.opacity(0.12) : GQColors.adaptiveOverlay(0.05))
                )

            Text(day)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(GQColors.textPrimary)

            Text(desc)
                .font(.system(size: 11))
                .foregroundStyle(GQColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var timelineConnector: some View {
        Rectangle()
            .fill(GQColors.borderDefault)
            .frame(height: 1)
            .frame(maxWidth: 24)
            .offset(y: -12)
    }

    // MARK: - Tier Cards

    private var savingsPercent: Int? {
        guard let monthly = subscriptionService.monthlyProduct,
              let yearly = subscriptionService.yearlyProduct else { return nil }
        let monthlyAnnual = monthly.price * 12
        guard monthlyAnnual > 0 else { return nil }
        let saved = (1 - yearly.price / monthlyAnnual) * 100
        let rounded = NSDecimalNumber(decimal: saved).intValue
        return rounded > 0 ? rounded : nil
    }

    private var yearlyPerMonth: String? {
        guard let yearly = subscriptionService.yearlyProduct else { return nil }
        let monthly = yearly.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: monthly as NSDecimalNumber)
    }

    private var monthlyPerYear: String? {
        guard let monthly = subscriptionService.monthlyProduct else { return nil }
        let yearly = monthly.price * 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: yearly as NSDecimalNumber)
    }

    @ViewBuilder
    private var tierCardsSection: some View {
        VStack(spacing: 12) {
            if let yearly = subscriptionService.yearlyProduct {
                let savings = savingsPercent.map { "Save \($0)%" }
                tierCard(
                    product: yearly,
                    label: "Yearly",
                    badge: "BEST VALUE",
                    savingsText: savings,
                    priceDetail: "\(yearly.displayPrice)/year",
                    subDetail: yearlyPerMonth.map { "Just \($0)/month" }
                )
            }

            if let monthly = subscriptionService.monthlyProduct {
                tierCard(
                    product: monthly,
                    label: "Monthly",
                    badge: nil,
                    savingsText: nil,
                    priceDetail: "\(monthly.displayPrice)/month",
                    subDetail: monthlyPerYear.map { "That's \($0)/year" }
                )
            }
        }
    }

    @ViewBuilder
    private func tierCard(product: Product, label: String, badge: String?, savingsText: String?, priceDetail: String, subDetail: String?) -> some View {
        let isSelected = selectedProduct?.id == product.id

        Button {
            withAnimation(GQMotion.press) {
                selectedProduct = product
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(label)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(GQColors.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(GQGradients.primary)
                                .clipShape(Capsule())
                        }

                        if let savingsText {
                            Text(savingsText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(GQColors.success)
                        }
                    }

                    Text(priceDetail)
                        .font(.subheadline)
                        .foregroundStyle(GQColors.textSecondary)

                    if let subDetail {
                        Text(subDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(GQColors.textTertiary)
                    }
                }

                Spacer()

                // Radio indicator
                Circle()
                    .fill(isSelected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(Color.clear))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQColors.borderProminent), lineWidth: 2)
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
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GQColors.deepBlue.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? AnyShapeStyle(GQGradients.primary) : AnyShapeStyle(GQGradients.glassBorder),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: .black.opacity(isSelected ? 0.10 : 0.06),
                radius: isSelected ? 12 : 8,
                y: isSelected ? 4 : 3
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
                    .foregroundStyle(GQColors.error)
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
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Try Free for 3 Days")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedProduct == nil || isPurchasing)
            .opacity(selectedProduct == nil || isPurchasing ? 0.5 : 1.0)

            Text("No payment due now. Cancel anytime.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(GQColors.success)

            Button {
                dismiss()
            } label: {
                Text("Maybe Later")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(GQColors.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
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
                    .foregroundStyle(GQColors.textSecondary)
            }
            .buttonStyle(.plain)

            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(GQColors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}
