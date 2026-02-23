//
//  PaywallView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 21.01.2026.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pm = PurchaseManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.tint)

                    Text("paywall.title")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("paywall.subtitle")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    FeatureRow(textKey: "paywall.feature.import_csv")
                    FeatureRow(textKey: "paywall.feature.export_all")
                    FeatureRow(textKey: "paywall.feature.multicurrency_coming")
                    FeatureRow(textKey: "paywall.feature.future_features")
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                Spacer()

                if pm.products.isEmpty {
                    ProgressView("paywall.loading")
                        .padding(.bottom, 8)
                } else {
                    VStack(spacing: 10) {
                        ForEach(pm.products, id: \.id) { product in
                            Button {
                                Task { await pm.purchase(product) }
                            } label: {
                                PaywallProductRow(product: product)
                            }
                            .buttonStyle(.plain)
                        }

                        Button("premium.restore") {
                            Task { await pm.restorePurchases() }
                        }
                        .font(.footnote)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                if let msg = pm.lastErrorMessage {
                    Text(msg) // это системная ошибка, можно оставить как есть
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .navigationTitle("settings.premium")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let textKey: LocalizedStringKey
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Text(textKey)
            Spacer()
        }
    }
}

private struct PaywallProductRow: View {
    let product: Product

    private var kind: ProductKind {
        ProductKind(productID: product.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(kind.titleKey)
                        .font(.headline)

                    if kind == .yearly {
                        Text("paywall.best_value")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                }

                Text(kind.subtitleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(product.displayPrice)
                    .font(.headline)

                Text(kind.periodSuffixKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private enum ProductKind: Equatable {
    case monthly
    case yearly
    case lifetime
    case unknown

    init(productID: String) {
        switch productID {
        case PurchaseManager.ProductID.premiumMonthly.rawValue: self = .monthly
        case PurchaseManager.ProductID.premiumYearly.rawValue: self = .yearly
        case PurchaseManager.ProductID.premiumLifetime.rawValue: self = .lifetime
        default: self = .unknown
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .monthly: "paywall.plan.monthly"
        case .yearly: "paywall.plan.yearly"
        case .lifetime: "paywall.plan.lifetime"
        case .unknown: "paywall.plan.unknown"
        }
    }

    var subtitleKey: LocalizedStringKey {
        switch self {
        case .monthly: "paywall.plan.monthly.subtitle"
        case .yearly: "paywall.plan.yearly.subtitle"
        case .lifetime: "paywall.plan.lifetime.subtitle"
        case .unknown: "paywall.plan.unknown.subtitle"
        }
    }

    var periodSuffixKey: LocalizedStringKey {
        switch self {
        case .monthly: "paywall.period.month"
        case .yearly: "paywall.period.year"
        case .lifetime: "paywall.period.once"
        case .unknown: "paywall.period.unknown"
        }
    }
}
