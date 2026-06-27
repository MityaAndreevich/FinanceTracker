//
//  PaywallView.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 21.01.2026.
//

import SwiftUI
import StoreKit

private let paywallMint = Color(red: 0.239, green: 0.863, blue: 0.592) // #3DDC97

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pm = PurchaseManager.shared

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://budgetcrab.app/PRIVACY_POLICY.html")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                        .padding(.top, 12)

                    if pm.products.isEmpty {
                        ProgressView("paywall.loading")
                            .padding(.vertical, 8)
                    } else {
                        planCardsSection
                    }

                    if let msg = pm.lastErrorMessage {
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    featureSection

                    footerSection
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("settings.premium")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
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
    }

    private var planCardsSection: some View {
        VStack(spacing: 12) {
            ForEach(sortedProducts(), id: \.id) { product in
                planCard(product: product, kind: ProductKind(productID: product.id))
            }
        }
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("paywall.features.header")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            FeatureRow(textKey: "paywall.feature.unlimited_transactions")
            FeatureRow(textKey: "paywall.feature.unlimited_csv")
            FeatureRow(textKey: "paywall.feature.custom_fields")
            FeatureRow(textKey: "paywall.feature.advanced_filters")
        }
        .padding(.top, 4)
    }

    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("paywall.legal.auto_renew")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Button {
                    Task { await pm.restorePurchases() }
                } label: {
                    Text("premium.restore")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("·")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)

                Link(destination: Self.privacyURL) {
                    Text("paywall.legal.privacy")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .underline()
                }

                Text("·")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)

                Link(destination: Self.termsURL) {
                    Text("paywall.legal.terms")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .underline()
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func planCard(product: Product, kind: ProductKind) -> some View {
        switch kind {
        case .yearly:
            YearlyPlanCard(product: product) {
                Task { await pm.purchase(product) }
            }
        case .lifetime:
            LifetimePlanCard(product: product) {
                Task { await pm.purchase(product) }
            }
        case .monthly:
            MonthlyPlanCard(product: product) {
                Task { await pm.purchase(product) }
            }
        case .unknown:
            EmptyView()
        }
    }

    private func sortedProducts() -> [Product] {
        let order: [ProductKind] = [.yearly, .lifetime, .monthly]
        return pm.products.sorted {
            let ai = order.firstIndex(of: ProductKind(productID: $0.id)) ?? 99
            let bi = order.firstIndex(of: ProductKind(productID: $1.id)) ?? 99
            return ai < bi
        }
    }
}

// MARK: - Plan Cards

private struct YearlyPlanCard: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("paywall.plan.yearly")
                            .font(.headline)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(paywallMint)
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text("paywall.plan.yearly.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .monospacedDigit()
            }

            Button(action: action) {
                Text("paywall.cta.yearly")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(paywallMint)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(paywallMint, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct LifetimePlanCard: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("paywall.plan.lifetime")
                        .font(.headline)
                    Text("paywall.plan.lifetime.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                BadgeLabel(textKey: "paywall.badge.founders_edition", systemImage: "crown.fill")
                BadgeLabel(textKey: "paywall.badge.family_sharing", systemImage: "person.2.fill")
            }

            Text("paywall.plan.lifetime.subline")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text("paywall.cta.lifetime")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.primary, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MonthlyPlanCard: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("paywall.plan.monthly")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("paywall.plan.monthly.subtitle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(product.displayPrice)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button(action: action) {
                Text("paywall.cta.monthly")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.secondary, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Supporting Views

private struct BadgeLabel: View {
    let textKey: LocalizedStringKey
    let systemImage: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(textKey)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(paywallMint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(paywallMint.opacity(0.12))
        .clipShape(Capsule())
    }
}

private struct FeatureRow: View {
    let textKey: LocalizedStringKey
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(textKey)
                .font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - Product Classification

private enum ProductKind: Equatable {
    case monthly
    case yearly
    case lifetime
    case unknown

    init(productID: String) {
        switch productID {
        case PurchaseManager.ProductID.premiumMonthly.rawValue:  self = .monthly
        case PurchaseManager.ProductID.premiumYearly.rawValue:   self = .yearly
        case PurchaseManager.ProductID.premiumLifetime.rawValue: self = .lifetime
        default:                                                  self = .unknown
        }
    }
}
