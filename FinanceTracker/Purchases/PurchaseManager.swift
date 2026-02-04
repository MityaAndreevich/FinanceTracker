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

    private var productIDs: [String] {
        ProductID.allCases.map { $0.rawValue }
    }
    
    var hasSubscriptionProducts: Bool {
            productIDs.contains(ProductID.premiumMonthly.rawValue)
            || productIDs.contains(ProductID.premiumYearly.rawValue)
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
        // Загружаем продукты
        Task { await loadProducts() }

        // Проверяем статус premium при запуске
        Task { await refreshPremiumStatus() }

        // Слушаем обновления транзакций (renewals, refunds, upgrades, etc.)
        updatesTask?.cancel()
        updatesTask = Task { await listenForTransactionUpdates() }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)

            // Порядок показа в paywall: yearly (best value), monthly, lifetime (pay once)
            self.products = orderProducts(storeProducts)

            // Если всё ок — чистим прошлые ошибки
            self.lastErrorMessage = nil
        } catch {
            self.lastErrorMessage = "Failed to load products: \(error.localizedDescription)"
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
                self.lastErrorMessage = nil

            case .userCancelled:
                break

            case .pending:
                // Family approval / SCA / etc.
                break

            @unknown default:
                break
            }
        } catch {
            self.lastErrorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    /// Это настоящая "Restore Purchases" для StoreKit 2
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPremiumStatus()
            self.lastErrorMessage = nil
        } catch {
            self.lastErrorMessage = "Restore failed: \(error.localizedDescription)"
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
                if transaction.revocationDate != nil {
                    continue
                }

                // 2) Признаём premium только по нашим Product IDs
                guard productIDs.contains(transaction.productID) else {
                    continue
                }

                // Этого достаточно: если есть активное entitlement — premium true
                premium = true
                break
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
            throw NSError(
                domain: "PurchaseManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed."]
            )
        case .verified(let safe):
            return safe
        }
    }
    
    @MainActor
    func refreshStatus() async {
        // 1) На будущее можно тут ещё обновлять products
        // await loadProducts()
        
        // 2) Сейчас главное — перечитать энтитлменты
        await refreshPremiumStatus()
    }
}
