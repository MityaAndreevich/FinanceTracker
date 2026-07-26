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
        case premiumMonthly  = "bc_premium_monthly"
        case premiumYearly   = "bc_premium_annual"
        case premiumLifetime = "bc_premium_lifetime"
    }

    /// Все наши продукты (и подписки, и lifetime)
    private var productIDs: [String] {
        ProductID.allCases.map(\.rawValue)
    }

    /// Все наши Product ID как Set — используется чистой функцией маппинга
    /// entitlement → premium (см. `evaluatePremium`) и её юнит-тестами.
    nonisolated static let allProductIDs: Set<String> = Set(ProductID.allCases.map(\.rawValue))

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

    /// True only for a REAL StoreKit entitlement: paid, auto-renewing, inside
    /// Apple's introductory free trial, or the lifetime non-consumable.
    ///
    /// This is NOT the gating flag. Feature gates read `AccessManager.isPremium`,
    /// which is this OR an active reverse trial. Keeping the two distinct is what
    /// lets a reverse-trial user still open the paywall and subscribe.
    @Published private(set) var hasPaidEntitlement: Bool = false

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
        updatesTask = Task { [weak self] in
            // `SKTransaction.updates` never ends, so this task lives as long as
            // the process. Capturing `self` strongly would close a real cycle
            // (self → updatesTask → closure → self) and `deinit` below could
            // then never run. Benign today — this type is a singleton — but the
            // weak capture is what makes that a property of the *shape* rather
            // than of the singleton, so a future per-view instantiation cannot
            // silently start leaking one audio-free StoreKit listener per view.
            for await result in SKTransaction.updates {
                guard let self else { return }
                await self.handleTransactionUpdate(result)
            }
        }
    }

    deinit {
        // Unreachable while `shared` is the only instance; correct the moment it
        // isn't. Pairs with the weak capture above — without it this would be
        // dead code, because the cycle would keep `deinit` from ever firing.
        updatesTask?.cancel()
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

        // ALWAYS re-read entitlements after any attempt — success, cancel,
        // pending, or throw. Critical for the "already subscribed" case: an
        // entitled user who somehow reached the paywall taps Subscribe, StoreKit
        // reports they already own it (which may surface as .userCancelled or a
        // throw), and this refresh flips hasPaidEntitlement=true so the gate
        // unlocks and the paywall auto-dismisses — instead of dead-ending on the
        // alert.
        await refreshPremiumStatus()
    }

    /// Это настоящая "Restore Purchases" для StoreKit 2
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPremiumStatus()
            lastErrorMessage = hasPaidEntitlement
                ? String(localized: "purchase.restored")
                : String(localized: "purchase.no_previous_purchases")
        } catch {
            lastErrorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Premium status

    /// Минимальное описание одного entitlement, достаточное для решения
    /// premium/не-premium. Существует, чтобы логику маппинга можно было
    /// покрыть детерминированными юнит-тестами без живой StoreKit-сессии
    /// (StoreKit.Transaction не сконструировать в тесте).
    struct EntitlementSnapshot: Equatable {
        let productID: String
        let isRevoked: Bool
    }

    /// ЕДИНСТВЕННЫЙ источник правды о том, что такое "premium".
    ///
    /// Premium == есть ХОТЬ ОДНО активное (не отозванное) entitlement на любой
    /// из наших продуктов. Сюда одинаково попадают: авто-продление в trial,
    /// оплаченное авто-продление, и lifetime non-consumable. Тип продукта и
    /// стадия подписки (trial vs paid) НЕ важны — важен только сам факт
    /// активного entitlement.
    nonisolated static func evaluatePremium(entitlements: [EntitlementSnapshot],
                                            knownProductIDs: Set<String> = allProductIDs) -> Bool {
        entitlements.contains { snapshot in
            !snapshot.isRevoked && knownProductIDs.contains(snapshot.productID)
        }
    }

    /// Pull-to-refresh будет дергать именно это.
    /// Оно безопасно обновляет isPremium на MainActor, читая актуальные
    /// entitlements из StoreKit и прогоняя их через чистую `evaluatePremium`.
    func refreshPremiumStatus() async {
        var snapshots: [EntitlementSnapshot] = []

        for await result in SKTransaction.currentEntitlements {
            do {
                let transaction = try verified(result)
                snapshots.append(
                    EntitlementSnapshot(
                        productID: transaction.productID,
                        isRevoked: transaction.revocationDate != nil
                    )
                )
            } catch {
                // ignore invalid entitlement
            }
        }

        hasPaidEntitlement = Self.evaluatePremium(entitlements: snapshots)
    }

    /// Удобный метод для экранов (и для .task / pull-to-refresh)
    func refreshStatus() async {
        await refreshPremiumStatus()
        // При желании позже можно добавить: await loadProducts()
    }

    // MARK: - Transaction updates

    /// One update from `SKTransaction.updates`. Split out of the `for await`
    /// loop so the loop itself can hold `self` weakly (see `start()`) — `self`
    /// is retained only for the duration of this call, not for the life of the
    /// never-ending sequence.
    private func handleTransactionUpdate(_ result: VerificationResult<SKTransaction>) async {
        do {
            let transaction = try verified(result)
            await transaction.finish()
            await refreshPremiumStatus()
        } catch {
            // ignore
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
