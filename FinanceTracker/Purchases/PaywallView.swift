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
    @StateObject private var access = AccessManager.shared

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://budgetcrab.app/PRIVACY_POLICY.html")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                        .padding(.top, 12)

                    productSection

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
        // The Pro screen is always dark for a premium look, regardless of the
        // app-wide appearance default (System). See AppearanceMode.
        .preferredColorScheme(.dark)
        // Reactive unlock backstop. If the user is already entitled when the
        // paywall opens — or becomes entitled while it's open (purchase, restore,
        // or the "already subscribed" recovery in PurchaseManager.purchase) —
        // dismiss immediately so they land back on the action they wanted, never
        // stuck staring at a paywall they've already paid past.
        //
        // Deliberately keyed on the PAID entitlement, not on AccessManager's
        // isPremium: a reverse-trial user is premium but has bought nothing, and
        // must still be able to open this screen and subscribe.
        .task { await pm.refreshStatus() }
        .onChange(of: pm.hasPaidEntitlement) { _, isPaid in
            if isPaid { dismiss() }
        }
        .onAppear {
            if pm.hasPaidEntitlement { dismiss() }
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

            if access.didReverseTrialLapseUnpaid {
                trialEndedNotice
                    .padding(.top, 8)
            } else if access.isReverseTrialActive {
                previewActiveNotice
                    .padding(.top, 8)
            }
        }
    }

    /// Shown while the 14-day reverse trial is still running. It names the free
    /// access the user already has — and names it as *our* preview, not as a
    /// subscription trial, because no card was taken and there is nothing to
    /// cancel. Being straight about that is the whole pitch of this app.
    private var previewActiveNotice: some View {
        Text(String(format: NSLocalizedString("paywall.preview_active.format", comment: ""),
                    access.trialDaysRemaining))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Shown after the 14-day reverse trial lapses. It names the loss plainly —
    /// and, just as plainly, promises that nothing was taken away. That promise is
    /// enforced by the caps themselves (they block adding, never delete), so this
    /// copy is a description of the code, not a reassurance we hope holds.
    private var trialEndedNotice: some View {
        VStack(spacing: 4) {
            Text("paywall.trial_ended.title")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("paywall.trial_ended.body")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Plan cards or the loading indicator. Under the paywall screenshot capture
    /// (DEBUG-only), StoreKit products can't load via `simctl launch`, so a
    /// deterministic mock of the plan cards is shown instead. Production builds
    /// always use the live StoreKit path.
    @ViewBuilder
    private var productSection: some View {
        #if DEBUG
        if ScreenshotMode.usesMockPaywall {
            mockPlanCardsSection
        } else {
            liveProductSection
        }
        #else
        liveProductSection
        #endif
    }

    @ViewBuilder
    private var liveProductSection: some View {
        if pm.products.isEmpty {
            ProgressView("paywall.loading")
                .padding(.vertical, 8)
        } else {
            planCardsSection
        }
    }

    #if DEBUG
    /// Screenshot-only mock. Prices are the exact App Store Connect base values
    /// (USD); every other string is the production localized key, so the cards
    /// render identically to the live paywall. Purchase actions are no-ops.
    private var mockPlanCardsSection: some View {
        // Derived from the mock prices with the SAME functions the live cards use,
        // so a screenshot can never advertise a per-month figure or a saving that
        // the real paywall wouldn't print.
        let annual: Decimal = 34.99
        let monthly: Decimal = 4.99
        let usd = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))

        return VStack(spacing: 12) {
            // No intro offer: the screenshot must show exactly what the store shows.
            YearlyPlanCard(
                displayPrice: "$34.99",
                perMonthText: PaywallPriceCopy.perMonthText(annualPrice: annual, format: usd),
                savingsPercent: PaywallPriceCopy.savingsPercent(annualPrice: annual,
                                                                monthlyPrice: monthly),
                freeTrialPeriod: nil
            ) {}
            LifetimePlanCard(displayPrice: "$99.99") {}
            MonthlyPlanCard(displayPrice: "$4.99") {}
        }
    }
    #endif

    private var planCardsSection: some View {
        VStack(spacing: 12) {
            ForEach(sortedProducts(), id: \.id) { product in
                planCard(product: product, kind: ProductKind(productID: product.id))
            }
        }
    }

    /// What Premium actually buys — and nothing else.
    ///
    /// This list used to promise "Unlimited transactions" and "All-time exports",
    /// which are FREE, plus "Custom fields" and "Advanced filters", which do not
    /// exist in the app at all. Selling a user a feature we don't ship is the
    /// exact dark pattern this product is positioned against, so the list now
    /// names only the four real premium capabilities, and states outright what
    /// stays free forever. If a row here stops being true, delete the row.
    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("paywall.features.header")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            FeatureRow(textKey: "paywall.feature.flexible_import")
            FeatureRow(textKey: "paywall.feature.unlimited_accounts")
            FeatureRow(textKey: "paywall.feature.unlimited_categories")
            FeatureRow(textKey: "paywall.feature.reports_alltime")

            Text("paywall.free_forever")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
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
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("·")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)

                Link(destination: Self.privacyURL) {
                    Text("paywall.legal.privacy")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .underline()
                }

                Text("·")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)

                Link(destination: Self.termsURL) {
                    Text("paywall.legal.terms")
                        .font(.footnote)
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
            // The savings claim is only as trustworthy as the monthly price it is
            // measured against: if that product didn't load, the badge stays away.
            let monthlyPrice = pm.products
                .first { ProductKind(productID: $0.id) == .monthly }?
                .price

            YearlyPlanCard(
                displayPrice: product.displayPrice,
                perMonthText: product.perMonthText,
                savingsPercent: PaywallPriceCopy.savingsPercent(annualPrice: product.price,
                                                                monthlyPrice: monthlyPrice),
                freeTrialPeriod: PaywallTrialCopy.freeTrialPeriodText(for: product.freeTrialOffer)
            ) {
                Task { await pm.purchase(product) }
            }
        case .lifetime:
            LifetimePlanCard(displayPrice: product.displayPrice) {
                Task { await pm.purchase(product) }
            }
        case .monthly:
            MonthlyPlanCard(displayPrice: product.displayPrice) {
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
    let displayPrice: String

    /// Annual price ÷ 12, already formatted in the storefront's currency, or nil
    /// when StoreKit gave us no price to divide. Nil hides the line: a wrong
    /// per-month figure is worse than no per-month figure.
    let perMonthText: String?

    /// Whole-percent saving vs twelve monthly renewals, or nil when it cannot be
    /// computed — no monthly product, or the annual plan simply isn't cheaper.
    let savingsPercent: Int?

    /// Localized length of the StoreKit free trial ("30 days"), or nil when the
    /// product carries no free introductory offer — which is the production
    /// case. When nil, this card says nothing whatsoever about a trial: no
    /// subtitle claim, no "Start free trial" CTA, no §3.1.2(a) modal, no
    /// disclosure. The 14-day reverse trial is the only trial we offer, and it
    /// is described as a preview elsewhere on this screen.
    let freeTrialPeriod: String?

    let action: () -> Void

    // Apple §3.1.2(a): the user must explicitly acknowledge the trial terms
    // BEFORE the StoreKit purchase sheet appears (Bug 7). The inline disclosure
    // below stays as always-visible information; this modal is the gate. Both
    // exist only on the trial path — with no trial there are no trial terms to
    // acknowledge, and the auto-renew disclosure in the footer covers the rest.
    @State private var showTrialConfirm = false

    private var hasFreeTrial: Bool { freeTrialPeriod != nil }

    private var subtitle: String {
        guard let freeTrialPeriod else {
            return NSLocalizedString("paywall.plan.yearly.subtitle", comment: "")
        }
        return String(format: NSLocalizedString("paywall.plan.yearly.subtitle.trial.format", comment: ""),
                      freeTrialPeriod, displayPrice)
    }

    private var ctaKey: LocalizedStringKey {
        hasFreeTrial ? "paywall.cta.yearly.trial" : "paywall.cta.yearly"
    }

    private var trialDisclosure: String {
        String(format: NSLocalizedString("paywall.trial.disclosure.format", comment: ""),
               freeTrialPeriod ?? "", displayPrice)
    }

    private var trialModalBody: String {
        String(format: NSLocalizedString("paywall.trial.modal.body.format", comment: ""),
               freeTrialPeriod ?? "", displayPrice)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("paywall.plan.yearly")
                            .font(.headline)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.brand)
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(displayPrice)
                        .font(.headline)
                        .monospacedDigit()
                    if let perMonthText {
                        Text(String(format: NSLocalizedString("paywall.yearly.per_month.format", comment: ""),
                                    perMonthText))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            HStack(spacing: 6) {
                BadgeLabel(textKey: "paywall.yearly.best_value", systemImage: "crown.fill")
                if let savingsPercent {
                    BadgeLabel(text: String(format: NSLocalizedString("paywall.yearly.save_amount.format", comment: ""),
                                            savingsPercent),
                               systemImage: "tag.fill")
                }
            }

            Button {
                // With no trial there is nothing to acknowledge, so go straight
                // to Apple's sheet rather than inventing a confirmation step.
                if hasFreeTrial {
                    showTrialConfirm = true
                } else {
                    action()
                }
            } label: {
                Text(ctaKey)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.brand)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .alert("paywall.trial.modal.title", isPresented: $showTrialConfirm) {
                Button("common.cancel", role: .cancel) {}
                Button("paywall.cta.yearly.trial") { action() }
            } message: {
                Text(trialModalBody)
            }

            if hasFreeTrial {
                // Apple §3.1.2(a): the free-trial CTA must disclose trial length,
                // the auto-renewing amount, and the cancellation path before
                // purchase. Length and price both come from StoreKit, so this
                // text cannot drift from what the App Store will actually charge.
                Text(trialDisclosure)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.brand, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct LifetimePlanCard: View {
    let displayPrice: String
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
                Text(displayPrice)
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
    let displayPrice: String
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
            Text(displayPrice)
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
    private let label: Text
    private let systemImage: String

    init(textKey: LocalizedStringKey, systemImage: String) {
        self.label = Text(textKey)
        self.systemImage = systemImage
    }

    /// For copy that was already localized AND interpolated (the savings percent).
    /// Takes `Text(verbatim:)` so the finished sentence is never mistaken for a
    /// lookup key and re-localized into itself.
    init(text: String, systemImage: String) {
        self.label = Text(verbatim: text)
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            label
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(Color.brand)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.brand.opacity(0.12))
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
