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

    // MARK: - Singleton

    static let shared = PurchaseManager()
    private init() {}

    // MARK: - Product IDs

    enum ProductID: String, CaseIterable {
        case premiumMonthly  = "ft_premium_monthly"
        case premiumYearly   = "ft_premium_yearly"
        case premiumLifetime = "ft_premium_lifetime"
    }

    /// Все наши продукты (и подписки, и lifetime)
    private var productIDs: [String] {
        ProductID.allCases.map(\.rawValue)
    }

    /// Только подписочные продукты (Monthly/Yearly)
    private var subscriptionIDs: Set<String> {
        [
            ProductID.premiumMonthly.rawValue,
            ProductID.premiumYearly.rawValue
        ]
    }

    /// Используется в UI: показывать ли Manage Subscription / Redeem Code
    /// Это должно зависеть от того, что реально загружено из StoreKit.
    var hasSubscriptionProducts: Bool {
        products.contains(where: { subscriptionIDs.contains($0.id) })
    }

    // MARK: - Published state

    /// Продукты для показа в Paywall (в нужном порядке)
    @Published private(set) var products: [Product] = []

    /// Главный флаг для gating (Import/Export All и т.д.)
    @Published private(set) var isPremium: Bool = false

    /// Можно показывать в UI, если нужно
    @Published var lastErrorMessage: String?

    // MARK: - Internals

    private var updatesTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func start() {
        // Загружаем продукты + обновляем премиум-статус
        Task { await loadProducts() }
        Task { await refreshPremiumStatus() }

        // Слушаем обновления транзакций (renewals, refunds, upgrades, etc.)
        updatesTask?.cancel()
        updatesTask = Task { await listenForTransactionUpdates() }
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = orderProducts(storeProducts)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    private func orderProducts(_ list: [Product]) -> [Product] {
        // Жёстко задаём порядок, чтобы UI был стабильный
        let order: [String: Int] = [
            ProductID.premiumYearly.rawValue: 0,
            ProductID.premiumMonthly.rawValue: 1,
            ProductID.premiumLifetime.rawValue: 2
        ]
        return list.sorted { (a, b) in
            (order[a.id] ?? 999) < (order[b.id] ?? 999)
        }
    }

    // MARK: - Purchase / Restore

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshPremiumStatus()
                lastErrorMessage = nil

            case .userCancelled:
                break

            case .pending:
                // Family approval / SCA / etc. — let user know it's awaiting approval.
                lastErrorMessage = String(localized: "purchase.pending_approval")

            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    /// Это настоящая "Restore Purchases" для StoreKit 2
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPremiumStatus()
            lastErrorMessage = isPremium
                ? String(localized: "purchase.restored")
                : String(localized: "purchase.no_previous_purchases")
        } catch {
            lastErrorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Premium status

    /// Pull-to-refresh будет дергать именно это.
    /// Оно безопасно обновляет isPremium на MainActor.
    func refreshPremiumStatus() async {
        var premium = false

        for await result in SKTransaction.currentEntitlements {
            do {
                let transaction = try verified(result)

                // 1) Игнорируем отозванные/рефанднутые
                if transaction.revocationDate != nil { continue }

                // 2) Признаём premium только по нашим Product IDs
                guard productIDs.contains(transaction.productID) else { continue }

                // Этого достаточно: если есть активное entitlement — premium true
                premium = true
                break
            } catch {
                // ignore invalid entitlement
            }
        }

        isPremium = premium
    }

    /// Удобный метод для экранов (и для .task / pull-to-refresh)
    func refreshStatus() async {
        await refreshPremiumStatus()
        // При желании позже можно добавить: await loadProducts()
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
            throw NSError(
                domain: "PurchaseManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed."]
            )
        case .verified(let safe):
            return safe
        }
    }
}
