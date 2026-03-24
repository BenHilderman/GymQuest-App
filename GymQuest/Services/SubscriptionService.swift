//
//  SubscriptionService.swift
//  GymQuest
//
//  Created by Benjamin Hilderman
//
//  StoreKit 2 subscription manager. Handles loading products, purchasing,
//  restoring, and listening for transaction updates.
//

import Foundation
import StoreKit
import SwiftUI
import Supabase

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    // Product IDs
    static let monthlyID = "com.liftai.pro.monthly"
    static let yearlyID = "com.liftai.pro.yearly"

    @Published var products: [Product] = []
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await updateSubscriptionStatus() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let ids: Set<String> = [Self.monthlyID, Self.yearlyID]
            products = try await Product.products(for: ids)
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            print("Restore failed: \(error)")
        }
    }

    // MARK: - Status

    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.monthlyID ||
                   transaction.productID == Self.yearlyID {
                    hasActiveSubscription = true
                }
            }
        }

        isPremium = hasActiveSubscription

        if FeatureFlags.shared.supabaseSyncEnabled, let userId = SupabaseAuthService.shared.currentUserId {
            Task {
                do {
                    try await SupabaseConfig.client.from("profiles")
                        .update(["is_premium": isPremium])
                        .eq("id", value: userId.uuidString)
                        .execute()
                } catch {
                    print("[SubscriptionService] Supabase premium sync failed: \(error)")
                }
            }
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? await self.checkVerified(result) {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let value):
            return value
        }
    }

    // MARK: - Helpers

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyID }
    }

    enum SubscriptionError: LocalizedError {
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .verificationFailed:
                return "Transaction verification failed."
            }
        }
    }
}
