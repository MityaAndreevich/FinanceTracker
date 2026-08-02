//
//  QuickEntryView.swift
//  FinanceTracker
//
//  Hero Quick Entry sheet — full-screen modal, replaces the + tab default destination.
//  "Use detailed form" link provides escape hatch to AddTransactionView (Brief 23A).
//

import SwiftUI
import SwiftData
import UIKit

struct QuickEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "USD"
    // One-shot hint pointing at the "Use detailed form" button, first + sheet only.
    @AppStorage("hasSeenOpenFormHint") private var hasSeenOpenFormHint = false

    @Query(sort: \Category.order, order: .forward)
    private var allCategories: [Category]

    @State private var inputText: String = ""
    @State private var parsed: QuickAddParsedInput? = nil
    @State private var categoryOverride: Category? = nil
    // A manual category pick (quick-chip or picker) sticks while the user keeps
    // editing the same entry, instead of being wiped by the next keystroke's
    // re-parse. Cleared only when the field is emptied. Lets the quick-chips be a
    // genuine one-tap accelerator (chip → keep typing → Save).
    @State private var categoryManuallyPicked = false
    // Single source of truth for the two sheets. Two stacked `.sheet(isPresented:)`
    // modifiers on the same view collide in SwiftUI (only one presents reliably),
    // which is what silently broke the tappable category badge. One `.sheet(item:)`
    // fixes it. `dismissAfterSheet` lets the form-fallback dismiss Quick Entry on
    // close while the category picker leaves Quick Entry open.
    private enum ActiveSheet: String, Identifiable {
        case category, addTxFallback
        var id: String { rawValue }
    }
    @State private var activeSheet: ActiveSheet? = nil
    @State private var dismissAfterSheet = false
    @State private var saveError = false
    // Success toast for the "Save & add another" path only. The primary Save
    // dismisses the sheet (the list surfaces its own confirmation), so this in-sheet
    // toast exists to confirm the save when we intentionally STAY on the entry screen.
    @State private var savedToast: LocalizedStringKey? = nil
    // Re-entrancy guard. `dismiss()` is animated/async, so a fast double-tap (or an
    // accessibility double-fire, or a late voice .ended event re-enabling the button)
    // could call handleSave() again before the view tears down — persisting the same
    // transaction 2-3×. Set once on the first successful entry and only reset on
    // failure so a retry is still possible. See Bug 7 (duplicate voice transactions).
    @State private var isSaving = false
    // Debounces an accidental double-fire of the Save action. Complements `isSaving`:
    // that guard covers a save still in flight, this one covers a second tap arriving
    // just after the first returned but before the view tears down. Content-blind, so
    // it cannot drop a distinct entry — see SaveActionGate.
    @State private var saveGate = SaveActionGate()
    @State private var placeholderIndex = 0
    @State private var parseTask: Task<Void, Never>? = nil
    @State private var appeared = false
    @State private var savePulseOn = false
    @State private var micPulseOn = false
    @FocusState private var isInputFocused: Bool

    // Bug 1 (P0): the preview chip's category name is code-resolved (not a SwiftUI
    // `Text(LocalizedStringKey:)`), so it must route through the active language's
    // bundle or it leaks the launch language (EN) while the rest of the app is RU.
    // Observing this also re-renders the chip when the user switches language live.
    @ObservedObject private var localizedBundle = LocalizedBundle.shared

    @StateObject private var voice = VoiceInputService()
    @State private var voiceErrorMessage: LocalizedStringKey? = nil
    @State private var voiceErrorShowSettings = false
    @State private var voiceErrorDismissTask: Task<Void, Never>? = nil

    private let testHookInput: String?
    private let placeholderTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private static let placeholderExamples: [LocalizedStringKey] = [
        "quick_entry.placeholder.1",
        "quick_entry.placeholder.2",
        "quick_entry.placeholder.3",
        "quick_entry.placeholder.4",
        "quick_entry.placeholder.5",
    ]

    init(testHookInput: String? = nil) {
        self.testHookInput = testHookInput
    }

    private var parsedReady: Bool { parsed != nil && !voice.isListening }

    private var resolvedCategoryName: String? {
        guard let p = parsed else { return nil }
        return effectiveCategory(for: p)?.displayName(bundle: localizedBundle.bundle)
    }

    /// Category that will actually be saved for a parsed input.
    ///
    /// A manual pick (`categoryOverride`) always wins. Otherwise resolution is
    /// delegated to `QuickAddSaveService.resolveCategory`, which honors a learned
    /// merchant mapping first, then the parser's keyword suggestion, then "Other".
    ///
    /// B4 (device test, this pass): the + sheet previously used `previewCategory`,
    /// which — per the earlier Round 8 decision — suppressed keyword *guesses* for
    /// expenses, so "50 кофе" showed "Other" here while the Dashboard quick-add
    /// (which uses `resolveCategory`) correctly showed "Food & Drink". That
    /// inconsistency read as "category not detected". We now use the same
    /// keyword-aware resolution on both surfaces; a learned correction still wins,
    /// and the user can always tap the chip to override.
    private func effectiveCategory(for p: QuickAddParsedInput) -> Category? {
        if let categoryOverride { return categoryOverride }
        return QuickAddSaveService.resolveCategory(for: p, in: modelContext)
    }

    private var saveA11yLabel: Text {
        guard let p = parsed, let catName = resolvedCategoryName else {
            return Text("quick_entry.save")
        }
        let amount = Money.format(cents: p.amountCents, currencyCode: defaultCurrencyCode)
        return Text(verbatim: String(format: NSLocalizedString("quick_entry.a11y.save_dynamic", comment: ""), amount, catName))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    // Empty-state prompt only; once parsed, the amount lives INSIDE
                    // the preview card (see previewCard) so there's no giant standalone
                    // hero eating the vertical budget while the keyboard is up.
                    amountHero

                    previewCard(parsed)
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)

            if saveError {
                errorBanner
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }

            if let voiceErrorMessage {
                voiceErrorBanner(voiceErrorMessage)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            bottomBar
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        // B7: this is a keyboard-driven input sheet — amount + preview + chips +
        // input + Save must all coexist above the keyboard. At accessibility sizes
        // that's physically impossible (verified: Ukrainian's long words clip the
        // preview card against the chips), so cap at the largest STANDARD size,
        // xxxLarge — still well above default,
        // so text stays large and legible without collapsing the layout. The
        // detailed form (accessed via "Открыть форму") has no such cap.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .animation(
            reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.72),
            value: parsed != nil
        )
        .animation(.easeInOut(duration: 0.25), value: saveError)
        .animation(.easeInOut(duration: 0.25), value: voiceErrorMessage != nil)
        .animation(.easeInOut(duration: 0.2), value: voice.isListening)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // Solid page surface — depth comes from layered surfaces, not gradients
        // (DESIGN_DIRECTION_v2 §2).
        .presentationBackground(Color.bcPage)
        // Confirms a save on the "Save & add another" path, where we stay put. As a
        // bottom overlay inside the sheet bounds it sits just above the keyboard (which
        // stays up so the next entry can be typed immediately), so it's never obscured.
        .confirmationToast($savedToast, duration: 2.0, style: .success)
        // MARK: Haptics (state-driven)
        .sensoryFeedback(.selection, trigger: appeared)
        .sensoryFeedback(.impact(weight: .light), trigger: parsed != nil) { old, new in
            !old && new
        }
        .sensoryFeedback(.warning, trigger: saveError) { old, new in
            !old && new
        }
        .sensoryFeedback(.warning, trigger: voiceErrorMessage != nil) { old, new in
            !old && new
        }
        .onAppear {
            if let hookInput = testHookInput {
                inputText = hookInput
                parsed = QuickAddParser.parse(hookInput)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }
            appeared = true
        }
        .onDisappear {
            voice.stop()
            voiceErrorDismissTask?.cancel()
        }
        .onReceive(placeholderTimer) { _ in
            guard !(isInputFocused && inputText.isEmpty) else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                placeholderIndex = (placeholderIndex + 1) % Self.placeholderExamples.count
            }
        }
        .onChange(of: voice.transcript) { _, newTranscript in
            // Live-bind the transcript into the hero input while listening.
            guard voice.isListening, !newTranscript.isEmpty else { return }
            inputText = newTranscript
        }
        .onChange(of: inputText) { _, newValue in
            // Typing wins over voice: if the text diverges from the live transcript
            // while listening, the user is typing — cancel voice cleanly.
            if voice.isListening && newValue != voice.transcript {
                voice.stop()
            }
            saveError = false
            // Clearing the field resets everything; otherwise a manual pick sticks
            // (see categoryManuallyPicked) so continuing to type doesn't wipe it.
            if newValue.isEmpty {
                categoryOverride = nil
                categoryManuallyPicked = false
            } else if !categoryManuallyPicked {
                categoryOverride = nil
            }
            parseTask?.cancel()
            parseTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(
                    reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.72)
                ) {
                    parsed = QuickAddParser.parse(newValue)
                }
            }
        }
        // When voice stops (manual tap or silence auto-stop), settle the parser
        // immediately instead of waiting for the typing debounce, so the Save button
        // enables as soon as dictation ends.
        .onChange(of: voice.isListening) { _, isListening in
            // Drive the mic's pulsing ring while listening.
            if isListening && !reduceMotion {
                micPulseOn = false
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    micPulseOn = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { micPulseOn = false }
            }

            guard !isListening, !inputText.isEmpty else { return }
            parseTask?.cancel()
            withAnimation(
                reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.72)
            ) {
                parsed = QuickAddParser.parse(inputText)
            }
        }
        // Save button ready-pulse: starts/stops when parsedReady toggles.
        .onChange(of: parsedReady, initial: true) { _, newReady in
            if newReady && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    savePulseOn = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    savePulseOn = false
                }
            }
        }
        .sheet(item: $activeSheet, onDismiss: {
            // Only the form-fallback should tear down Quick Entry; the category
            // picker leaves it open so the user can keep editing the preview.
            if dismissAfterSheet {
                dismissAfterSheet = false
                dismiss()
            }
        }) { sheet in
            switch sheet {
            case .category:
                CategoryPickerSheet(currentType: parsed?.typeRaw ?? TransactionType.expense.raw) { picked in
                    categoryOverride = picked
                    categoryManuallyPicked = true
                }
            case .addTxFallback:
                NavigationStack {
                    AddTransactionView(prefillText: inputText)
                }
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bcTextSecondary)
                    .frame(width: 34, height: 34)
                    .background(Color.bcSurface2)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.bcDivider, lineWidth: 1))
            }
            .accessibilityLabel(Text("common.close"))

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "lock.iphone")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bcAccent)
                    .accessibilityHidden(true)
                Text("quick_entry.privacy_chip")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.bcTextSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.bcSurface2, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.bcDivider, lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("quick_entry.a11y.privacy_chip"))
        }
    }

    // MARK: - Amount hero (front-and-center, reflects the live parse)

    /// B7: only the empty-state prompt now. Once a parse lands, the amount is
    /// rendered inside `previewCard` (grouped with its category/merchant), so the
    /// parsed state no longer carries a tall standalone hero that squeezed the
    /// scroll and forced the preview / chips to clip under the keyboard.
    @ViewBuilder
    private var amountHero: some View {
        // The empty-state prompt ("Введите или скажите сумму"). Mounted for the WHOLE
        // empty state (parsed == nil) at a STABLE full width so it can never re-wrap
        // one char per line across the voice⇄text focus toggle.
        //
        // Item 1 (device QA, "+"-sheet jank): this label used to COLLAPSE to height 0
        // + opacity 0 on focus, driven by `.animation(value: isInputFocused)` on the
        // scroll content. That animation ran at the exact moment the keyboard-show
        // animation was shrinking the scroll region — two animations racing over the
        // same vertical space. The race is what produced the transient non-finite
        // layout pass (`Invalid frame dimension` spam), the two-stage "jerky rise",
        // AND the hint appearing to be "eaten" by the keyboard. It stays mounted and
        // visible now: it lives in the scroll region ABOVE the fixed input/Save
        // cluster, which the keyboard pushes up, so the hint is never occluded, and
        // the chip row it once overlapped moved into the bottom cluster (B7), so
        // there's nothing left to clip against. No focus-driven size change → no race.
        if parsed == nil {
            Text("quick_entry.prompt.amount")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(Color.bcTextMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Quick category chips (one-tap assignment for the most-used)

    /// Up to six most-used categories for the current direction — the "primary"
    /// (shown-by-default) ones from the taxonomy, back-filled with the rest.
    /// Read on-device from the local store; no network.
    private var quickChipCategories: [Category] {
        let kind = parsed?.typeRaw ?? TransactionType.expense.raw
        let ofKind = allCategories.filter { $0.kindRaw == kind }
        let primary = ofKind.filter { $0.isPrimary }
        let ordered = primary + ofKind.filter { !$0.isPrimary }
        return Array(ordered.prefix(6))
    }

    @ViewBuilder
    private var quickChips: some View {
        if !quickChipCategories.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(quickChipCategories, id: \.uuid) { cat in
                        quickChip(cat)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .accessibilityLabel(Text("quick_entry.a11y.quick_categories"))
        }
    }

    private func quickChip(_ cat: Category) -> some View {
        // Brief #3: the chip row is a SECONDARY correction tool — it must not
        // out-shout the hero input + Save on first look. Smaller tiles (40 vs 46),
        // muted lighter labels, and tighter width keep the multi-color tiles legible
        // for recognition while visually yielding to the primary action. The selected
        // chip still lifts (accent ring + primary label) so a made pick reads clearly.
        let isSelected = categoryOverride?.uuid == cat.uuid
        let tileSize: CGFloat = 40
        return Button {
            pickChipCategory(cat)
        } label: {
            VStack(spacing: 5) {
                CategoryIconTile(category: cat, size: tileSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: tileSize * 0.3, style: .continuous)
                            .strokeBorder(cat.themeColor, lineWidth: isSelected ? 2 : 0)
                    )
                Text(cat.displayName())
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.bcTextPrimary : Color.bcTextMuted)
                    .lineLimit(1)
            }
            .frame(width: 58)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(cat.displayName()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Assigns a category from a quick-chip tap. Sticky (survives further typing)
    /// until the field is cleared. Fast path: chip → Save, no picker needed.
    private func pickChipCategory(_ cat: Category) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if categoryOverride?.uuid == cat.uuid {
                categoryOverride = nil
                categoryManuallyPicked = false
            } else {
                categoryOverride = cat
                categoryManuallyPicked = true
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Live preview card (fills the old void; skeleton before any parse)

    @ViewBuilder
    private func previewCard(_ parsedOrNil: QuickAddParsedInput?) -> some View {
        // Progressive disclosure (Brief #3): the detail card materializes ONLY after a
        // value is parsed. The old empty-state skeleton ("Details appear here as you
        // type") duplicated the input placeholder and crowded the first look, so the
        // empty state now stays calm — just the single prompt line + the hero input.
        if let p = parsedOrNil {
            let resolvedCategory = effectiveCategory(for: p)
            let isIncome = p.typeRaw == TransactionType.income.raw

            VStack(alignment: .leading, spacing: 14) {

                // Amount now lives here (the standalone hero is gone in the parsed
                // state, B7). Grouped with the direction pill so the card reads as
                // one unit and the layout fits above the keyboard.
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(Money.format(cents: p.amountCents, currencyCode: defaultCurrencyCode))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.bcTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                        .privacySensitive(true)
                        .accessibilityHidden(true)   // voiced by the Save button label

                    Spacer(minLength: 8)

                    directionPill(isIncome: isIncome)
                }

                // Tappable category + merchant row → opens the picker.
                Button {
                    activeSheet = .category
                } label: {
                    HStack(spacing: 12) {
                        categoryTile(resolvedCategory)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(previewTitle(p, resolvedCategory))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.bcTextPrimary)
                                .lineLimit(1)
                            if let sub = previewSubtitle(p, resolvedCategory) {
                                Text(sub)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.bcTextSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.bcTextMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("quickadd.a11y.change_category"))
                .accessibilityValue(Text(resolvedCategory?.displayName(bundle: localizedBundle.bundle) ?? ""))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .bcCard(padding: 16)
        }
    }

    private func directionPill(isIncome: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isIncome ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text(isIncome ? "analytics.label.income" : "analytics.label.expense")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                // B7: never wrap ("ВИТРА-ТА" on two lines grew the card and clipped
                // the category subtitle in uk at large type). One line; the amount
                // beside it yields via its minimumScaleFactor instead.
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(Color.moneyDirectional(isPositive: isIncome))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.moneyDirectional(isPositive: isIncome).opacity(0.14), in: Capsule())
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func categoryTile(_ category: Category?) -> some View {
        if let category {
            CategoryIconTile(category: category, size: 40)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.bcSurface2)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "tag")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bcTextMuted)
                )
                .accessibilityHidden(true)
        }
    }

    private func previewTitle(_ p: QuickAddParsedInput, _ cat: Category?) -> String {
        if let m = p.merchant?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return m }
        return cat?.displayName(bundle: localizedBundle.bundle)
            ?? String(localized: "quickadd.preview.no_category", bundle: localizedBundle.bundle)
    }

    /// Subtitle only when the merchant is the title (so we can surface the
    /// category underneath); otherwise nil so we don't repeat it.
    private func previewSubtitle(_ p: QuickAddParsedInput, _ cat: Category?) -> String? {
        guard let m = p.merchant?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty else { return nil }
        return cat?.displayName(bundle: localizedBundle.bundle)
            ?? String(localized: "quickadd.preview.no_category", bundle: localizedBundle.bundle)
    }

    // MARK: - Error banner

    private var errorBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.bcDanger)
            // This banner is driven solely by `saveError`, set in handleSave()'s
            // catch — which is unreachable unless `parsed != nil`. So it ALWAYS means
            // "the save failed", never "couldn't parse". Showing the old
            // "Couldn't read that" copy while the parsed amount is on screen was the
            // reported contradiction; use the save-failure message instead.
            Text("add.error.save_failed")
                .font(.subheadline)
                .foregroundStyle(Color.bcDanger)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.bcDanger.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Bottom cluster (input bar / recording state · Save · form link)

    private var bottomBar: some View {
        VStack(spacing: 14) {
            // B7: chips are ANCHORED in the fixed cluster, directly above the input,
            // with a fixed 14pt gap. Because they share this VStack with the input,
            // the keyboard pushes the whole cluster up as a unit — the input can
            // never ride up over the chip labels (the bug), in any locale or Dynamic
            // Type size. The scroll region above (prompt/amount + preview) absorbs
            // any squeeze instead.
            //
            // The extra 10pt bottom padding (on top of the VStack's 14pt spacing =
            // 24pt total) gives the chip row breathing room from the input line so it
            // no longer reads as cramped once data is entered. Scoped to this one gap;
            // input→Save and Save→form-link stay at the 14pt VStack spacing.
            //
            // Brief #3: chips are the PRE-parse accelerator (pick a category, then type)
            // and hide the moment a value is parsed. Two wins: (1) the parsed preview
            // card gains ~90pt so its category/merchant row is no longer clipped under
            // the keyboard on a phone-height sheet — previously only the amount showed;
            // (2) it de-emphasizes the picker in the parsed state, where the card's own
            // tappable category row is the correction affordance. Progressive disclosure.
            if parsed == nil {
                quickChips
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // The NL input bar flips to a live recording panel while dictating —
            // voice is a headline feature, so it takes over rather than hiding in a
            // corner. Both reuse the same on-device services.
            //
            // Item 2 (device QA): previously this was an if/else that INSERTED and
            // REMOVED the two bars (different heights), so toggling modes changed
            // the cluster height mid-animation and the whole sheet lurched ("torn/
            // janky movement"). Now both bars are always mounted in a ZStack, so the
            // slot height is fixed (the taller of the two) and switching modes only
            // cross-fades opacity — no reflow. Keeping the text field mounted also
            // avoids tearing down its keyboard toolbar on every toggle.
            ZStack {
                inputBar
                    .opacity(voice.isListening ? 0 : 1)
                    .allowsHitTesting(!voice.isListening)
                    .accessibilityHidden(voice.isListening)
                recordingBar
                    .opacity(voice.isListening ? 1 : 0)
                    .allowsHitTesting(voice.isListening)
                    .accessibilityHidden(!voice.isListening)
            }

            saveButton

            // Secondary rapid-entry action (v1.0): save the current entry WITHOUT
            // dismissing, so several transactions can be logged in a row. Deliberately
            // NOT a post-save "add another?" modal — that would tax the common
            // single-entry case; instead this is an always-available secondary button
            // that only appears once there's something to save (parsed != nil), so the
            // empty state stays calm. Plain tinted text keeps it clearly subordinate to
            // the filled Save above. Runs the SAME guarded save path; on failure it
            // rolls back and does NOT clear/advance (see handleSave(addAnother:)).
            if parsed != nil {
                Button {
                    handleSave(addAnother: true)
                } label: {
                    Text("quick_entry.save_add_another")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.bcAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .transition(.opacity)
                .accessibilityLabel(Text("quick_entry.save_add_another"))
            }

            // One-shot hint (Brief 28 Part B): the first time the + sheet opens, point
            // at the detailed-form button. Empty-state only so it never crowds the
            // tall parsed preview under the keyboard; dismissible and shown once.
            if parsed == nil && !voice.isListening && !hasSeenOpenFormHint {
                // Points DOWN: the "Use detailed form" button it refers to sits
                // directly below this hint (device QA round 1 #3 — the hand was
                // pointing up, away from its target).
                InlineHintBubble(text: "onboarding.hint.openform", pointing: .down) {
                    withAnimation { hasSeenOpenFormHint = true }
                }
            }

            // Secondary escape hatch to the detailed form. Brief 28-A #2: previously a
            // faint grey footnote that read as inert text. Now a proper BORDERED button
            // — SF Symbol + label, tinted outline, full-width ≥44 pt target — so it's
            // unmistakably tappable, while staying clearly SECONDARY to the filled mint
            // Save above it (outline vs. fill carries the hierarchy).
            Button {
                dismissAfterSheet = true
                activeSheet = .addTxFallback
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                    Text("quick_entry.use_form")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.bcAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.bcAccent.opacity(0.10), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.bcAccent.opacity(0.45), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("quick_entry.use_form"))
        }
    }

    // MARK: - Input bar (the one-line NL field)

    private var inputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.bcAccent)
                .accessibilityHidden(true)

            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text(Self.placeholderExamples[placeholderIndex])
                        .id(placeholderIndex)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.bcTextMuted)
                        .transition(.opacity.animation(.easeOut(duration: 0.5)))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextField("", text: $inputText, axis: .vertical)
                    .plainTextEntry()
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .lineLimit(1...3)
                    .tint(Color.bcAccent)
                    .foregroundStyle(Color.bcTextPrimary)
                    .focused($isInputFocused)
                    .accessibilityLabel(Text("quick_entry.a11y.input_label"))
                    .accessibilityHint(Text("quick_entry.a11y.input_hint"))
                    .accessibilityValue(
                        inputText.isEmpty ? Text("quick_entry.a11y.input_empty") : Text(verbatim: inputText)
                    )
                    // B8 (device): with the keyboard up — especially once the preview
                    // grows the input to 3 lines on an SE/mini — the pinned Save button
                    // could be squeezed under the keyboard, leaving no way to commit
                    // without dismissing it. A keyboard-accessory Save always sits
                    // directly above the keyboard, reachable on every device size and
                    // Dynamic Type setting. The field uses axis: .vertical (return =
                    // newline for long voice transcripts), so a toolbar button — not
                    // submitLabel/onSubmit — is the reliable commit affordance.
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button {
                                isInputFocused = false
                                handleSave()
                            } label: {
                                Label("quick_entry.save", systemImage: "checkmark.circle.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(parsed != nil ? Color.bcAccent : Color.bcTextMuted)
                            }
                            .disabled(parsed == nil || isSaving)
                            .accessibilityLabel(saveA11yLabel)
                        }
                    }
            }

            // Bug 7: always show the mic so voice is discoverable in every locale.
            // When on-device recognition isn't installed for the user's language,
            // tapping surfaces a friendly "type instead" toast (toggleVoice →
            // .deviceUnavailable) rather than hiding the control with no explanation.
            micButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.bcSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isInputFocused ? Color.bcAccent.opacity(0.6) : Color.bcDivider, lineWidth: 1)
        )
    }

    /// Idle mic — a mint affordance inside the input bar. Tapping starts on-device
    /// dictation and flips the bar to `recordingBar`.
    private var micButton: some View {
        Button {
            toggleVoice()
        } label: {
            ZStack {
                Circle().fill(Color.bcAccent.opacity(0.16))
                Image(systemName: "mic.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bcAccent)
            }
            .frame(width: 40, height: 40)
        }
        .accessibilityLabel(Text("quick_entry.a11y.mic_idle"))
        .accessibilityHint(Text("quick_entry.a11y.mic_hint"))
    }

    // MARK: - Recording state (alive: waveform + on-device caption + stop)

    private var recordingBar: some View {
        HStack(spacing: 14) {
            voiceWaveform
                .frame(width: 46, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("quick_entry.listening")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bcTextPrimary)
                if !voice.transcript.isEmpty {
                    Text(verbatim: voice.transcript)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bcTextSecondary)
                        .lineLimit(1)
                        .privacySensitive(true)
                }
            }

            Spacer(minLength: 8)

            Button {
                toggleVoice()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.bcAccent.opacity(0.4), lineWidth: 2)
                        .scaleEffect(micPulseOn ? 1.2 : 1.0)
                        .opacity(micPulseOn ? 0.15 : 0.8)
                    Circle().fill(Color.bcAccent)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black)
                }
                .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("quick_entry.a11y.mic_listening"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.bcSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.bcAccent.opacity(0.6), lineWidth: 1.5)
        )
    }

    /// Live mint waveform — pure time-driven animation (feedback, not chrome).
    /// Static bars under Reduce Motion.
    private var voiceWaveform: some View {
        let baseHeights: [CGFloat] = [10, 20, 14, 24, 12]
        return Group {
            if reduceMotion {
                HStack(spacing: 3) {
                    ForEach(0..<baseHeights.count, id: \.self) { i in
                        Capsule().fill(Color.bcAccent).frame(width: 4, height: baseHeights[i])
                    }
                }
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    HStack(spacing: 3) {
                        ForEach(0..<baseHeights.count, id: \.self) { i in
                            let phase = sin(t * 6 + Double(i) * 0.9)
                            let h = 8 + (phase + 1) / 2 * 18   // 8…26pt
                            Capsule().fill(Color.bcAccent).frame(width: 4, height: h)
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Save button

    private var saveButton: some View {
        let ready = parsed != nil
        return Button {
            handleSave()
        } label: {
            HStack(spacing: 8) {
                if ready {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text("quick_entry.save")
                    .font(.headline)
            }
            .foregroundStyle(ready ? Color.black : Color.bcTextMuted)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(ready ? Color.bcAccent : Color.bcSurface2)
            .clipShape(Capsule())
            .overlay {
                if !ready {
                    Capsule().strokeBorder(Color.bcDivider, lineWidth: 1)
                }
            }
            .scaleEffect(savePulseOn ? 1.02 : 1.0)
        }
        .disabled(!ready || isSaving)
        .accessibilityLabel(saveA11yLabel)
    }

    // MARK: - Voice error banner

    @ViewBuilder
    private func voiceErrorBanner(_ message: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.slash.fill")
                .font(.caption)
                .foregroundStyle(Color.bcDanger)
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.bcDanger)

            if voiceErrorShowSettings {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("quick_entry.voice.settings")
                        .font(.caption.weight(.semibold))
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Voice control

    private func toggleVoice() {
        Task {
            voiceErrorDismissTask?.cancel()
            withAnimation {
                voiceErrorMessage = nil
                voiceErrorShowSettings = false
            }

            if voice.isListening {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                voice.stop()
                return
            }

            let auth = await voice.requestAuthorizationIfNeeded()
            switch auth {
            case .authorized:
                do {
                    try await voice.start()
                    FeatureUsageSignals.markUsed(.voiceEntry)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } catch {
                    showVoiceError("quick_entry.voice.fail_start", showSettings: false)
                }
            case .denied:
                showVoiceError("quick_entry.voice.denied_open_settings", showSettings: true)
            case .deviceUnavailable:
                // On-device recognition isn't installed for this language.
                showVoiceError("voice.unavailable_for_lang", showSettings: false)
            case .restricted:
                showVoiceError("quick_entry.voice.unavailable", showSettings: false)
            case .undetermined:
                break
            }
        }
    }

    private func showVoiceError(_ key: LocalizedStringKey, showSettings: Bool) {
        voiceErrorDismissTask?.cancel()
        withAnimation {
            voiceErrorMessage = key
            voiceErrorShowSettings = showSettings
        }
        voiceErrorDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation {
                voiceErrorMessage = nil
                voiceErrorShowSettings = false
            }
        }
    }

    // MARK: - Save

    /// Saves the current parsed entry through the guarded save path.
    ///
    /// - Parameter addAnother: when `true`, STAY on the entry screen (clear the form,
    ///   confirm with a toast, re-focus the input for the next entry) instead of
    ///   dismissing. The save mechanics — the `QuickAddSaveService.save` call and its
    ///   rollback-on-failure behavior — are identical either way; only the success tail
    ///   differs. A failed save rolls back and does NOT clear/advance in either mode.
    private func handleSave(addAnother: Bool = false) {
        // Re-entrancy guard: ignore repeat invocations while a save is still in flight.
        // On the single-entry happy path the view dismisses, so isSaving is intentionally
        // not reset there; the add-another path re-enables it via resetForNextEntry().
        guard let p = parsed, !isSaving else { return }

        // Debounce an accidental double-fire of THIS action (fast double-tap, a11y
        // double-fire, a late voice .ended). Deliberately content-blind: it can only
        // ever drop a second tap, never a distinct entry — unlike the content dedup it
        // replaces, which silently ate a second identical coffee. "Save & add another"
        // is unaffected: the form must be retyped, which takes far longer than 500ms.
        saveGate.submit {
            isSaving = true
            withAnimation(.easeInOut(duration: 0.1)) { savePulseOn = false }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            do {
                _ = try QuickAddSaveService.save(
                    parsed: p,
                    modelContext: modelContext,
                    defaultCurrencyCode: defaultCurrencyCode,
                    overrideCategory: effectiveCategory(for: p)
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                RatingPromptCoordinator.recordTransactionSaved()
                if addAnother {
                    resetForNextEntry()
                } else {
                    dismiss()
                }
            } catch {
                logSaveFailure("QuickEntryView.handleSave", error)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                isSaving = false        // allow a retry after a genuine failure
                saveGate.reset()        // ...and don't debounce that retry away
                withAnimation {
                    saveError = true
                }
            }
        }
    }

    /// Returns the screen to a neutral, ready-to-type state after a successful
    /// "Save & add another" — clears the input and derived parse, drops any manual
    /// category pick, shows the success toast, and re-focuses the input so the next
    /// entry can be typed immediately. Only reached after a save actually persisted.
    private func resetForNextEntry() {
        parseTask?.cancel()
        voice.stop()
        withAnimation(
            reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.72)
        ) {
            inputText = ""
            parsed = nil
            categoryOverride = nil
            categoryManuallyPicked = false
            saveError = false
        }
        isSaving = false
        savedToast = "quick_entry.saved"
        isInputFocused = true
    }
}

#Preview {
    QuickEntryView()
        .modelContainer(
            for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self],
            inMemory: true
        )
}

#Preview("Screenshot — parsed valid") {
    QuickEntryView(testHookInput: "67 gas")
        .preferredColorScheme(.dark)
        .modelContainer(for: [Transaction.self, Category.self, Source.self, MerchantCategoryLearning.self], inMemory: true)
}
