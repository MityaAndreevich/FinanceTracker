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

    @State private var inputText: String = ""
    @State private var parsed: QuickAddParsedInput? = nil
    @State private var categoryOverride: Category? = nil
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
    @State private var placeholderIndex = 0
    @State private var parseTask: Task<Void, Never>? = nil
    @State private var appeared = false
    @State private var savePulseOn = false
    @State private var micPulseOn = false
    @FocusState private var isInputFocused: Bool

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
        return effectiveCategory(for: p)?.displayName()
    }

    /// Category that will actually be saved for a parsed input.
    ///
    /// Round 8 device feedback: silently auto-assigning a *guessed* expense
    /// category (e.g. "транспорт" for "купил кофе") felt presumptuous and was
    /// often wrong. So expenses now default to "Other" until the user taps the
    /// badge to choose — no silent keyword guessing. Income keeps its automatic
    /// assignment because the taxonomy has a single dedicated "Income" category,
    /// which is correct rather than a guess.
    private func effectiveCategory(for p: QuickAddParsedInput) -> Category? {
        if let categoryOverride { return categoryOverride }
        if p.typeRaw == TransactionType.income.raw {
            return QuickAddSaveService.resolveCategory(for: p, in: modelContext)
        }
        let all = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        return all.first { $0.name == "Other" && $0.kindRaw == p.typeRaw }
            ?? all.first { $0.name == "Other" }
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

            Spacer(minLength: 32)

            heroTextField
                .padding(.horizontal, 32)

            if let p = parsed {
                previewCard(p)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.92, anchor: .top).combined(with: .opacity)
                    )
            }

            Spacer(minLength: 20)

            if saveError {
                errorBanner
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            if let voiceErrorMessage {
                voiceErrorBanner(voiceErrorMessage)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
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
        .presentationBackground {
            Color(.systemBackground)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.04),
                            Color.clear,
                            Color.accentColor.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
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
            // A fresh parse invalidates any manual category override.
            categoryOverride = nil
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .accessibilityLabel(Text("common.close"))

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "lock.iphone")
                    .font(.caption)
                    .accessibilityHidden(true)
                Text("quick_entry.privacy_chip")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("quick_entry.a11y.privacy_chip"))
        }
    }

    // MARK: - Hero text input

    private var heroTextField: some View {
        ZStack {
            if inputText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.accentColor.opacity(0.4))
                    Text(Self.placeholderExamples[placeholderIndex])
                        .id(placeholderIndex)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.tertiary)
                        .transition(.opacity.animation(.easeOut(duration: 0.5)))
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            TextField("", text: $inputText, axis: .vertical)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .tint(.accentColor)
                .focused($isInputFocused)
                .accessibilityLabel(Text("quick_entry.a11y.input_label"))
                .accessibilityHint(Text("quick_entry.a11y.input_hint"))
                .accessibilityValue(
                    inputText.isEmpty ? Text("quick_entry.a11y.input_empty") : Text(verbatim: inputText)
                )
        }
    }

    // MARK: - Live preview card

    @ViewBuilder
    private func previewCard(_ p: QuickAddParsedInput) -> some View {
        let resolvedCategory = effectiveCategory(for: p)
        let isIncome = p.typeRaw == TransactionType.income.raw

        VStack(spacing: Spacing.compact) {
            // Direction pill — carries the income/expense color so the amount
            // itself can stay maximum-contrast (daylight legibility).
            HStack(spacing: Spacing.xs) {
                Image(systemName: isIncome ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.weight(.bold))
                Text(isIncome ? "analytics.label.income" : "analytics.label.expense")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .foregroundStyle(Color.money(isPositive: isIncome))
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 5)
            .background(Color.money(isPositive: isIncome).opacity(0.14), in: Capsule())
            .accessibilityHidden(true)

            // Hero amount — 60pt, high contrast (primary label), monospaced.
            // The leading +/− already encodes direction (color-blind safe).
            Text(Money.formatSigned(
                cents: p.amountCents,
                isPositive: isIncome,
                currencyCode: defaultCurrencyCode
            ))
            .font(.bcDisplay.monospacedDigit())
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityHidden(true)   // voiced by the Save button label

            // Category chip + merchant.
            HStack(spacing: Spacing.xs) {
                categoryBadge(resolvedCategory, isIncome: isIncome)

                if let merchant = p.merchant {
                    Text(merchant)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.default)
        .cardSurface(cornerRadius: CornerRadius.cardLarge)
    }

    /// Tappable category chip — opens the picker so the user can override the
    /// auto-detected category. Prominent: category icon sits in a tinted color
    /// chip so the control reads as a button, not text.
    @ViewBuilder
    private func categoryBadge(_ category: Category?, isIncome: Bool) -> some View {
        let tint = Color.money(isPositive: isIncome)
        Button {
            activeSheet = .category
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: (category?.icon?.isEmpty == false ? category!.icon! : "tag.fill"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(tint.opacity(0.16), in: Circle())
                Text(category?.displayName() ?? String(localized: "quickadd.preview.no_category"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 5)
            .padding(.trailing, Spacing.s)
            .padding(.vertical, 5)
            .background(Color.bcSeparator, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("quickadd.a11y.change_category"))
        .accessibilityValue(Text(category?.displayName() ?? ""))
    }

    // MARK: - Error banner

    private var errorBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text("quick_entry.fail_unparseable")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Bottom CTA bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if voice.isAvailable {
                    micButton
                }

                Button {
                    handleSave()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: parsed == nil ? "questionmark.circle" : "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("quick_entry.save")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: parsed == nil
                                    ? [Color.gray.opacity(0.5), Color.gray.opacity(0.4)]
                                    : [Color.accentColor, Color.accentColor.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            if parsed != nil {
                                // Subtle shimmer when ready to save.
                                LinearGradient(
                                    colors: [Color.white.opacity(0.0), Color.white.opacity(0.15), Color.white.opacity(0.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        }
                    )
                    .clipShape(Capsule())
                    .scaleEffect(savePulseOn ? 1.02 : 1.0)
                    .shadow(color: parsed == nil ? .clear : Color.accentColor.opacity(0.4), radius: 8, y: 4)
                }
                .disabled(parsed == nil)
                .accessibilityLabel(saveA11yLabel)
            }

            Button {
                dismissAfterSheet = true
                activeSheet = .addTxFallback
            } label: {
                Text("quick_entry.use_form")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Mic button

    private var micButton: some View {
        Button {
            toggleVoice()
        } label: {
            ZStack {
                Circle()
                    .fill(voice.isListening ? Color.red.opacity(0.15) : Color(.tertiarySystemFill))

                if voice.isListening {
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 2)
                        .scaleEffect(micPulseOn ? 1.15 : 1.0)
                        .opacity(micPulseOn ? 0.2 : 0.8)
                }

                Image(systemName: voice.isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(voice.isListening ? Color.red : Color.secondary)
                    .symbolEffect(.variableColor.iterative.reversing, isActive: voice.isListening)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 60, height: 60)
        }
        .accessibilityLabel(
            Text(voice.isListening ? "quick_entry.a11y.mic_listening" : "quick_entry.a11y.mic_idle")
        )
        .accessibilityHint(Text("quick_entry.a11y.mic_hint"))
    }

    // MARK: - Voice error banner

    @ViewBuilder
    private func voiceErrorBanner(_ message: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.slash.fill")
                .font(.caption)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)

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
            case .restricted, .deviceUnavailable:
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
        guard let p = parsed else { return }
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
