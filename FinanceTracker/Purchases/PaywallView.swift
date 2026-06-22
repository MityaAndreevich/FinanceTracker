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

    // MARK: - Legal URLs
    // NOTE: Replace these placeholders with your real published URLs before App Store submission.
    // Apple's standard EULA can be used in App Store Connect if you don't want a custom one.
    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://example.com/financetracker/privacy")!

    var body: some View {
        NavigationStack {
            ScrollView {
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
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    // MARK: - Required legal disclosures
                    legalSection
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
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

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("paywall.legal.auto_renew")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Link(destination: Self.termsURL) {
                    Text("paywall.legal.terms")
                        .font(.caption2)
                        .underline()
                }

                Text("paywall.legal.and")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Link(destination: Self.privacyURL) {
                    Text("paywall.legal.privacy")
                        .font(.caption2)
                        .underline()
                }
            }
            .accessibilityElement(children: .contain)
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
