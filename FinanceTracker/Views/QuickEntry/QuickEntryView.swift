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
    // Re-entrancy guard. `dismiss()` is animated/async, so a fast double-tap (or an
    // accessibility double-fire, or a late voice .ended event re-enabling the button)
    // could call handleSave() again before the view tears down — persisting the same
    // transaction 2-3×. Set once on the first successful entry and only reset on
    // failure so a retry is still possible. See Bug 7 (duplicate voice transactions).
    @State private var isSaving = false
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

    private var amountHero: some View {
        VStack(spacing: 8) {
            if let p = parsed {
                Text(Money.format(cents: p.amountCents, currencyCode: defaultCurrencyCode))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.bcTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .contentTransition(.numericText())
                    .privacySensitive(true)
                    .accessibilityHidden(true)   // voiced by the Save button label
            } else {
                Text("quick_entry.prompt.amount")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.bcTextMuted)
                    .multilineTextAlignment(.center)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
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
                HStack(spacing: 14) {
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
        let isSelected = categoryOverride?.uuid == cat.uuid
        return Button {
            pickChipCategory(cat)
        } label: {
            VStack(spacing: 6) {
                CategoryIconTile(category: cat, size: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 46 * 0.3, style: .continuous)
                            .strokeBorder(cat.themeColor, lineWidth: isSelected ? 2 : 0)
                    )
                Text(cat.displayName())
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.bcTextPrimary : Color.bcTextSecondary)
                    .lineLimit(1)
            }
            .frame(width: 66)
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
        VStack(alignment: .leading, spacing: 14) {
            if let p = parsedOrNil {
                let resolvedCategory = effectiveCategory(for: p)
                let isIncome = p.typeRaw == TransactionType.income.raw

                directionPill(isIncome: isIncome)

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
            } else {
                previewSkeleton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bcCard(padding: 16)
    }

    private func directionPill(isIncome: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isIncome ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text(isIncome ? "analytics.label.income" : "analytics.label.expense")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.5)
        }
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

    /// Calm placeholder before anything is parsed — an invitation, not a blank.
    /// Compact single row so it never crowds the chips + input when the keyboard
    /// is up; the full detail card replaces it the moment a parse lands.
    private var previewSkeleton: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.bcSurface2)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bcTextMuted)
                )
            Text("quick_entry.preview.hint")
                .font(.system(size: 14))
                .foregroundStyle(Color.bcTextMuted)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("quick_entry.preview.hint"))
    }

    // MARK: - Error banner

    private var errorBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.bcDanger)
            Text("quick_entry.fail_unparseable")
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
            // Quick-chips sit directly above the input so they stay visible above
            // the keyboard (one-tap category assignment while typing).
            quickChips

            // The NL input bar flips to a live recording panel while dictating —
            // voice is a headline feature, so it takes over rather than hiding in a
            // corner. Both reuse the same on-device services.
            if voice.isListening {
                recordingBar
                    .transition(.opacity)
            } else {
                inputBar
                    .transition(.opacity)
            }

            saveButton

            Button {
                dismissAfterSheet = true
                activeSheet = .addTxFallback
            } label: {
                Text("quick_entry.use_form")
                    .font(.footnote)
                    .foregroundStyle(Color.bcTextSecondary)
            }
            .buttonStyle(.plain)
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

    private func handleSave() {
        // Re-entrancy guard: ignore repeat invocations while the first save is still
        // in flight (the view dismisses on success, so isSaving is intentionally not
        // reset on the happy path).
        guard let p = parsed, !isSaving else { return }
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
            dismiss()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            isSaving = false   // allow a retry after a genuine failure
            withAnimation {
                saveError = true
            }
        }
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
