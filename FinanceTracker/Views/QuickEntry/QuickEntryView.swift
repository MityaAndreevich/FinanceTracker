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
    @State private var showAddTxFallback = false
    @State private var saveError = false
    @State private var placeholderIndex = 0
    @State private var parseTask: Task<Void, Never>? = nil
    @State private var appeared = false
    @State private var savePulseOn = false
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
        return QuickAddSaveService.resolveCategory(for: p, in: modelContext)?.displayName()
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
        .sheet(isPresented: $showAddTxFallback, onDismiss: { dismiss() }) {
            NavigationStack {
                AddTransactionView(prefillText: inputText)
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
                Text(Self.placeholderExamples[placeholderIndex])
                    .id(placeholderIndex)
                    .font(.system(size: 32, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeOut(duration: 0.5)))
                    .accessibilityHidden(true)
            }

            TextField("", text: $inputText, axis: .vertical)
                .font(.system(size: 32, weight: .medium))
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
        let resolvedCategory = QuickAddSaveService.resolveCategory(for: p, in: modelContext)
        let isIncome = p.typeRaw == TransactionType.income.raw

        HStack(alignment: .center, spacing: 12) {
            Text(Money.formatSigned(
                cents: p.amountCents,
                isPositive: isIncome,
                currencyCode: defaultCurrencyCode
            ))
            .font(.system(size: 28, weight: .semibold).monospacedDigit())
            .foregroundStyle(isIncome ? Color.green : Color.red)

            if let catName = resolvedCategory?.displayName() {
                Text(catName)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }

            if let merchant = p.merchant {
                Text(merchant)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Decorative — save button label already voices amount + category for screen readers.
        .accessibilityHidden(true)
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
                    Text("quick_entry.save")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .opacity(parsed == nil ? 0.4 : 1)
                        .scaleEffect(savePulseOn ? 1.02 : 1.0)
                }
                .disabled(parsed == nil)
                .accessibilityLabel(saveA11yLabel)
            }

            Button {
                showAddTxFallback = true
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
            Image(systemName: voice.isListening ? "waveform.circle.fill" : "mic.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(voice.isListening ? Color.red : Color.secondary)
                .symbolEffect(.pulse.byLayer, options: .repeating, isActive: voice.isListening)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 56, height: 56)
                .background(Circle().fill(.thinMaterial))
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
                defaultCurrencyCode: defaultCurrencyCode
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
