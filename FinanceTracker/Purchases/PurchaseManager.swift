//
//  PurchaseManager.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 21.01.2026.
//

import Foundation
import StoreKit

typealias SKTransaction = StoreKit.Transaction

@MainActor
final class PurchaseManager: ObservableObject {

    // MARK: - Products

    static let shared = PurchaseManager()

    private let productIDs: [String] = [
        "ft_premium_monthly",
        "ft_premium_yearly",
        "ft_premium_lifetime"
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium: Bool = false
    @Published var lastErrorMessage: String?

    private var updatesTask: Task<Void, Never>?

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    func start() {
        // 1) Load products
        Task { await loadProducts() }

        // 2) Initial entitlement check
        Task { await refreshPremiumStatus() }

        // 3) Listen for transaction updates (refunds, renewals, etc.)
        updatesTask?.cancel()
        updatesTask = Task { await listenForTransactionUpdates() }
    }

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            // Стабильный порядок (годовой сначала обычно выгоднее)
            self.products = storeProducts.sorted { $0.id > $1.id }
        } catch {
            self.lastErrorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshPremiumStatus()

            case .userCancelled:
                break

            case .pending:
                // Например, Family approval / Strong Customer Auth
                break

            @unknown default:
                break
            }
        } catch {
            self.lastErrorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        // StoreKit 2: обычно достаточно refresh entitlements
        await refreshPremiumStatus()
    }

    // MARK: - Premium status

    func refreshPremiumStatus() async {
        // Проверяем активные энтайтлменты (подписки/покупки)
        var premium = false

        for await result in SKTransaction.currentEntitlements {
            do {
                let transaction = try verified(result)

                // Признаём премиумом только наши подписки
                if productIDs.contains(transaction.productID) {
                    // Для подписок важно ещё убедиться, что не отозвана
                    premium = true
                    break
                }
            } catch {
                // ignore invalid entitlement
            }
        }

        self.isPremium = premium
    }

    // MARK: - Transaction updates

    private func listenForTransactionUpdates() async {
        for await result in SKTransaction.updates {
            do {
                let transaction = try verified(result)
                await transaction.finish()
                await refreshPremiumStatus()
            } catch {
                // ignore
            }
        }
    }

    // MARK: - Verification helper

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "PurchaseManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Transaction verification failed."
            ])
        case .verified(let safe):
            return safe
        }
    }
}
