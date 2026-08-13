//
//  LocaleCompletenessTests.swift
//  FinanceTrackerTests
//
//  Guards the locale parity decision: v1.0 ships 5 fully-translated locales
//  (EN, RU, ES, pt-BR, UK), each with the same key set as English (491 keys ×
//  5 locales = 2,455 entries). A drifting count means a key was added without
//  translating it — which would surface raw keys (e.g. "common.done") in the UI
//  and risk rejection.
//

import XCTest
@testable import FinanceTracker

final class LocaleCompletenessTests: XCTestCase {

    private let locales = ["en", "ru", "es", "pt-BR", "uk"]

    private func strings(for localization: String) -> [String: String]? {
        guard let path = Bundle.main.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil,
            forLocalization: localization
        ), let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            return nil
        }
        return dict
    }

    func test_all_four_locales_match_english_key_set() throws {
        guard let en = strings(for: "en") else {
            return XCTFail("Missing English Localizable.strings")
        }
        let enKeys = Set(en.keys)
        // Bumped 2026-06-28 (Wave 1 Fix #3): +3 yearly plan framing keys
        // (paywall.yearly.best_value, paywall.yearly.save_amount, paywall.yearly.per_month). Was 461 before this pass.
        // Lowered 2026-06-28 (Wave 3 Fix #14 prune): −4 onboarding keys made dead by
        // language auto-detect (onboarding.language.title/subtitle, onboarding.next/back). Was 464.
        // Bumped 2026-06-28 (Fix 1): +4 Horizon mode-toggle keys
        // (analytics.horizon.mode.net/expenses/income/combined). Was 460.
        // Bumped 2026-06-28 (Fix 5): +4 restored onboarding language-screen keys
        // (onboarding.language.title/subtitle, onboarding.next/back). Was 464.
        // Bumped 2026-06-28 (Round 10 i18n leak fix): +21 keys referenced in code but
        // missing from ALL locales — 10 tx_detail.* (raw-key leak in TransactionDetailView),
        // 10 data.* import/export results (DataSettingsView), premium.section.manage. Was 468.
        // Bumped 2026-06-29 (Bug 9): +2 add-confirmation toast keys
        // (cs.toast.category_added, cs.toast.source_added). Was 489.
        // Bumped 2026-06-29 (Bug 5): +1 Apple §3.1.2(a) trial disclosure key
        // (paywall.trial.disclosure). Was 491.
        // Bumped 2026-06-29 (Bug 7): +1 voice fallback key
        // (voice.unavailable_for_lang). Was 492.
        // Bumped 2026-06-29 (Bug 12/Q1-C): +1 auto-save toast key
        // (quickadd.saved.tap_to_edit). Was 493.
        // Bumped 2026-06-29 (Quick Add sensitivity setting): +5 keys — label,
        // caption, and 3 segment labels (confirm/balanced/instant). The brief
        // estimated +3, but a 3-position picker plus its label and caption needs
        // 5 distinct strings. Was 494.
        // Bumped 2026-06-29 (shake-to-undo): +1 undo confirmation toast key
        // (quickadd.undo.confirmed). Was 499.
        // Bumped 2026-06-30 (Bug 17): +4 add-transaction error keys referenced via
        // showErrorKey(...) but missing from ALL locales — they leaked raw to the
        // user (add.error.unknown/select_category/invalid_amount/save_failed). Was 500.
        // Bumped 2026-06-30 (Bug 7): +2 pre-purchase trial disclosure modal keys
        // (paywall.trial.modal.title, paywall.trial.modal.body). Was 504.
        // Bumped 2026-06-30 (Sprint B Bug 18): +1 duplicate-category-name error key
        // (category.error.duplicate_name). Was 506.
        // Bumped 2026-06-30 (Sprint B patch Bug 6): +1 DEBUG-only redeem-code hint
        // documenting the local-StoreKit code-redemption limitation
        // (premium.redeem.debug_hint). Was 507.
        // Bumped 2026-06-30 (Brief 35 Bug 19): +3 general.* keys that leaked raw in the
        // Reset alert — referenced via the showInfo(titleKey:messageKey:) helper and the
        // infoMessageKey @State default, so the old scanner never saw them
        // (general.reset_success.message, general.reset_failed.message,
        // general.info.default). testAllLocalizedKeysExist was also strengthened to
        // catch the `…Key:` argument / `…Key =` assignment class. Was 508.
        // Bumped 2026-06-30 (Brief 36 Bug 34.5): +1 category-specific save-error key
        // (category.error.save_failed). AddCategorySheet was showing the TRANSACTION
        // error (add.error.save_failed → "Не удалось сохранить транзакцию") when a
        // category save failed. Was 511.
        // Refreshed 2026-07-04 (save/duplication cluster pass): baseline had drifted
        // to 530 from prior legitimate key additions that never updated this magic
        // number. Verified all 5 locales carry exactly 530 keys (full parity) before
        // bumping — no missing/raw keys, just a stale count. Was 512.
        // 2026-07-04 (Brief 28 Part A): +3 for the Dashboard budget CTA/edit entry
        // (dashboard.budget.cta.title/subtitle, dashboard.budget.edit.a11y). Was 530.
        // 2026-07-04 (Brief 28 Part B/E): +15 for the first-run coach-mark flow
        // (onboarding.greeting.*, onboarding.skip, onboarding.coach.*, onboarding.firstwin.*).
        // onboarding.next was reused, not added. Was 533.
        // 2026-07-04 (Brief 28 Part C): +2 for the demo sandbox banner
        // (onboarding.demo.banner, onboarding.demo.clear). Was 548.
        // 2026-07-04 (Brief 28 Part B hints): +3 for the one-shot inline hints
        // (onboarding.hint.openform, onboarding.hint.period, onboarding.hint.got_it). Was 550.
        // 2026-07-05 (device QA round 1 #7): +2 for the honest "Recent" list header
        // and its "See all" link (dashboard.recent, dashboard.see_all). Was 553.
        // Bumped 2026-07-05 (Device QA round 2 #2): +3 honest empty-state keys
        // (transactions.noresults.title/clear, transactions.noneinperiod.title) so a
        // search/filter-hidden list reads as "No results", not "Add your first". Was 555.
        // 2026-07-05 (Quick Entry UX polish, Item 1): +2 for the "Save & add another"
        // secondary action and its success toast (quick_entry.save_add_another,
        // quick_entry.saved). Was 558.
        // 2026-07-06 (CSV integrity brief, Item 2): +1 for the import dedup summary
        // line (data.import.result.duplicates_skipped.format). Was 560.
        // 2026-07-07 (Analytics v1.0.1 brief): +5 for the donut "Other" bucket
        // (analytics.breakdown.other) and the Pace velocity cue
        // (analytics.pace.title/faster/on/under). Measured 568 after the addition;
        // the prior literal (561) had already drifted −2 vs the real 563 baseline
        // (all 5 locales stayed in parity, so only this hardcoded number was stale).
        // 2026-07-07 (Widget redesign v1.0.1): +5 for the redesigned widget's
        // safe-to-spend hero + no-budget/over-budget copy (widget.safe_to_spend,
        // widget.over_budget, widget.hero.spent, widget.of_budget.format,
        // widget.of_earned.format). All 5 locales carry them in parity. Was 568.
        // 2026-07-08 (Widget polish v1.0.1, Item 0): +2 gain-frame hero keys —
        // widget.overspent (over-income danger label) and dashboard.hero.spent
        // (app hero last-resort "Spent" label, aligned with the widget precedence).
        // All 5 locales carry them in parity. Was 573.
        // 2026-07-08 (Flexible CSV import v1.0.1, Tier 2): +48 for the column-
        // mapping sheet (import.map.*), the mapped-row failure reasons
        // (csv.import.error.missing_date/invalid_date/invalid_amount/
        // debit_credit_empty/debit_credit_both/unknown_type/row), and two result
        // counters (data.import.result.failed_rows/currency_assumed). All 5
        // locales carry them in parity. Was 575.
        // 2026-07-08 (Item 2 ambiguous-date safety): +3 for the date-interpretation
        // row in the mapping sheet (import.map.date.ambiguous / reads.format /
        // unreadable.format). All 5 locales in parity. Was 623.
        // 2026-07-08 (Decimal-convention detection, symmetric with date order): +6
        // for the amount-interpretation row + decimal picker (import.map.decimal.auto
        // /ambiguous, import.map.amount.reads/unreadable.format), the separator
        // failure reason (csv.import.error.separator_inconsistent), and the summary
        // hint (data.import.result.separator_hint). All 5 locales in parity. Was 626.
        // 2026-07-11 (v1.0.2 possible-duplicate review): +13 for the row badge
        // (transactions.duplicate.badge), the review banner (duplicates.banner.*)
        // and the resolve flow (duplicates.review.*: explainer, keep/delete,
        // keep_all/delete_all + its confirmation, empty state). No count is ever
        // interpolated into a sentence — ru/uk have three plural forms and the
        // project ships no .stringsdict. All 5 locales in parity. Was 632.
        // 2026-07-11 (v1.0.2 monetization, Item 1): +1 for the reverse-trial status
        // line shown in Settings (premium.status.trial.format). All 5 locales in
        // parity. Was 645.
        // 2026-07-11 (v1.0.2 monetization, Item 3): +2 for the free-tier cap hints
        // shown under a locked Add button (cs.sources.cap_hint,
        // cs.categories.cap_hint). Both promise, in every locale, that existing
        // accounts/categories stay. All 5 locales in parity. Was 646.
        // 2026-07-11 (v1.0.2 monetization, Item 2): net +1. REMOVED 6 paywall feature
        // keys that were no longer true — unlimited_transactions / alltime_exports /
        // privacy_ondevice / unlimited_csv name things that are FREE, and
        // custom_fields / advanced_filters name features the app does not have at
        // all. ADDED 7: the four real premium capabilities (flexible_import,
        // unlimited_accounts, unlimited_categories, reports_alltime), the
        // free-forever promise (paywall.free_forever), and the trial-end notice
        // (paywall.trial_ended.title/body). All 5 locales in parity. Was 648.
        // 2026-07-14 (v1.0.2 paywall copy): net +3. REMOVED 2 keys that hardcoded a
        // StoreKit free trial we no longer offer — paywall.trial.disclosure and
        // paywall.trial.modal.body baked "30 days" and "$34.99" straight into the
        // copy. ADDED 5: the trial disclosure/modal-body/subtitle/CTA as *format*
        // keys fed by StoreKit's actual offer (so they can never go stale, and are
        // never rendered when there is no offer), plus paywall.preview_active.format
        // for the running 14-day reverse trial. All 5 locales in parity. Was 649.
        // 2026-07-14 (Learn & Tips hub): net +9. ADDED 10 chrome keys for the hub
        // (settings.learn_tips + learn.*). REMOVED settings.help, whose Settings row
        // and HelpView container both dissolved into the hub — retired in the same
        // commit as its last code reference, since testNoMissingLocalizationKeys
        // rightly fails on a referenced-but-absent key.
        // Tip *content* deliberately does not appear here: it lives in tips.json per
        // locale, so a 365-item library can land without touching this baseline.
        // All 5 locales in parity. Was 652.
        // 2026-07-14 (proactive alerts): +15. The alerts settings chrome, the three
        // blocked states (no budget / notifications denied / paywall), and the two
        // gain-framed notification bodies. Both bodies are month-scoped because the
        // amount is the whole month's remainder — calling it a week figure would
        // overstate what is safe to spend. All 5 locales in parity. Was 661.
        // 2026-07-14 (chart domain guard): +1. `analytics.horizon.no_data` — Horizon
        // now refuses to plot a flat series (a zero-height Y domain traps inside
        // Charts), and a flat series is a statement about the user's data, not a
        // transient layout condition, so it gets a sentence rather than a blank
        // 320pt hole. All 5 locales in parity. Was 676.
        // 2026-07-15 (v1.0.2 paywall clarity): net +13. REMOVED the 6 keys of the
        // one-sided "what Premium gives you" checklist (paywall.features.header,
        // paywall.feature.*, paywall.free_forever). ADDED 19 for the free-vs-Premium
        // table: header, the two column titles, 10 row labels, 3 spoken cell values
        // and the row a11y format, plus the two data-safety keys. The table's CELLS
        // are not localized at all — they derive from AppCapability, so a gate change
        // can never leave the copy behind. All 5 locales in parity. Was 677.
        // 2026-07-15 (v1.0.2 Learn hub seen-only): net +1. The hub now lists only
        // tips already revealed as a past tip of the day, so REMOVED learn.all_tips
        // ("All tips" — no longer true, the future library isn't browsable) and
        // ADDED learn.seen_tips (the section header) + learn.more_each_day (the
        // day-1 line when nothing but today has been seen). All 5 locales in parity.
        // Was 690.
        // 2026-07-15 (per-user collection-under-lock): net +2. The collection is now
        // driven by the user's own usage, so ADDED learn.unlocked_count (the "X of Y
        // unlocked" progress line) + learn.collection_complete (shown once every tip
        // is unlocked). learn.more_each_day is retained. All 5 locales in parity.
        // Was 691.
        // 2026-07-21 (1.0.3 Velocity Dashboard, Item 2): net +5. The hero leads
        // with the DAILY allowance, so ADDED dashboard.safe_today,
        // dashboard.days_left (non-currency subtitle), dashboard.budget_used.a11y
        // (the status ring's VoiceOver line) + the two gain-framed pace verdicts
        // dashboard.pace.on_track / dashboard.pace.hold_the_line.
        // dashboard.safe_per_day is retained (superseded, still shipped). All 5
        // locales in parity. Was 693.
        // 2026-07-21 (1.0.3 feedback channel, Item 5): net +6. The privacy-first
        // feedback mail composer — feedback.row, feedback.body_prompt, the
        // no-mail-account fallback trio (mail_unavailable.title/.caption,
        // copy_address) and feedback.copied. All 5 locales in parity. Was 698.
        // 2026-07-21 (1.0.3 V2 schema + migration safety belt): net +17.
        // category.uncategorized (the §1.4 nil-category contract) + the launch
        // safety surfaces — premigration.* (5), migration.working,
        // backupfail.* (3), floor.* (4), restore.* (3). All 5 locales in
        // parity. Was 704.
        // 2026-07-21 (1.0.3 split transactions, Item 4): net +11. The split
        // editor (split.* — section, add_part, amount placeholder, picker,
        // hint, over-sum/incomplete validation, remainder/fully-assigned
        // footers), the detail breakdown section, and the drill-down's
        // partial-amounts footnote. All 5 locales in parity. Was 721.
        // 2026-07-21 (1.0.3 category limits, Item 3): net +6. The limit sheet
        // (limit.sheet.title/.caption, limit.amount.placeholder, limit.clear),
        // the row's limit label, and the gain-framed "X left in {category}"
        // notification body. All 5 locales in parity. Was 732.
        // 2026-07-25 (search/analytics split consistency): net +3. The row's
        // split badge, the search-results footnote explaining why a row's amount
        // can exceed the share Analytics counts, and the editor note for a
        // fully-assigned split whose category therefore receives nothing.
        // All 5 locales in parity. Was 739.
        // 2026-08-02 (feedback usage summary, 1.0.4): net +17. The consent
        // screen (explainer, toggle + caption, preview header, subject note,
        // continue) and the 11 summary lines the user reads before sending.
        // All 5 locales in parity. Was 742.
        // 2026-08-05 (guarded delete paths): net +2. A failed shake-undo and a
        // failed swipe-delete both used to be silent; each now says what did NOT
        // happen. All 5 locales in parity. Was 760.
        // 2026-08-06 (guarded save at the audited view sites): net +1. One shared
        // "nothing was changed" message for the Categories & Accounts sheets.
        // All 5 locales in parity. Was 762.
        // 2026-08-10 (split discoverability, 1.0.4 gate 1): net +1. The Add
        // screen now names splitting under the category row; the detail-view
        // entry point reuses the four split.* keys that already existed.
        // All 5 locales in parity. Was 763.
        // 2026-08-10 (silent-failure sweep, Tier 1): net +1. Offer-code
        // redemption failure now says so instead of a DEBUG-only print that was
        // compiled out of the only builds where redemption works. The account
        // sheet's failure reuses the existing shared cs.error.save_failed.
        // All 5 locales in parity. Was 764.
        // 2026-08-12 (orphan sweep, 1.0.5): net -15, the first NEGATIVE movement of
        // this baseline. Eleven `tutorial.*` keys for the retired 3-page carousel —
        // no view has rendered them since Brief 28 Part E replaced it with the
        // coach-mark flow — and four `general.*restart_onboarding*` keys for a
        // Settings button that was removed because it silently did nothing and its
        // alert described a language/currency screen that had also been deleted.
        // `tutorial.page3.demo_offer` is DELIBERATELY KEPT: it is the one survivor
        // of the carousel and still renders in GeneralSettingView.
        // Orphaned strings describing a deleted screen are the raw material of the
        // next false finding — `tutorial.page3.bullet1` ("100% on-device — no cloud,
        // no servers") was cited in DESIGN_ICLOUD_SYNC §2.1 as shipped copy that
        // sync would falsify, when in fact nothing rendered it.
        // All 5 locales in parity. Was 765.
        // 2026-08-12 (discoverability set, 1.0.5): net +4. `common.undo` for the
        // visible Undo now on the Quick Add toast (undo previously existed ONLY as
        // an undiscoverable shake gesture); `settings.setup_guide` + its footer for
        // the Settings row that finally names the widget and the Siri intents —
        // both configured outside the app, so no in-app hint can reach them; and
        // `cs.category.limit_hint`, naming monthly category limits where the user is
        // already looking at their categories. No new ARTICLE copy: the setup guide
        // reuses help.widget.* and help.siri.*, which already existed.
        // All 5 locales in parity. Was 750.
        // 2026-08-13 (Brief 36 item 1, 1.0.5): net -1. `category.show_all` deleted as
        // an orphan — the two-step "Show all" picker it named was removed when
        // CategoryPickerSheet became the single shared picker for both entry
        // surfaces, and no Swift file has referenced the key since.
        // This is the case §252 above predicted, one step worse: the orphan had a
        // LIVE twin. `cs.category.secondary_label` ("Under “Show all”") was not
        // merely unrendered — it shipped to users in all 5 locales at
        // CategoriesSourcesView.swift:445, naming a control they could hunt for and
        // never find. It now reads "Not shown by default", the exact complement of
        // its `cs.category.primary_label` twin and of the toggle beside it.
        // NOTE for whoever edits this pair next: `isPrimary` false does NOT hide a
        // category. CategoryPickerSheet filters on kind + search only (:35–38), so
        // every category stays reachable there; the flag only decides the Quick
        // Entry chip row (QuickEntryView.swift:387–388) and the Siri default
        // (CategoryEntity.swift:63). Copy implying reduced availability is wrong.
        // All 5 locales in parity. Was 754.
        XCTAssertEqual(enKeys.count, 753, "English baseline changed; update the expected count.")

        for locale in locales {
            guard let dict = strings(for: locale) else {
                XCTFail("Missing locale: \(locale)")
                continue
            }
            let keys = Set(dict.keys)
            let missing = enKeys.subtracting(keys)
            let extra = keys.subtracting(enKeys)
            XCTAssertTrue(missing.isEmpty, "\(locale) missing keys: \(missing.sorted())")
            XCTAssertTrue(extra.isEmpty, "\(locale) has extra keys not in EN: \(extra.sorted())")
            XCTAssertEqual(dict.count, enKeys.count, "\(locale) has \(dict.count) keys (expected \(enKeys.count))")
        }
    }

    func test_common_done_present_and_not_raw_in_all_locales() {
        for locale in locales {
            guard let dict = strings(for: locale) else {
                XCTFail("Missing locale: \(locale)")
                continue
            }
            let value = dict["common.done"]
            XCTAssertNotNil(value, "common.done missing in \(locale)")
            XCTAssertFalse((value ?? "").isEmpty, "common.done empty in \(locale)")
            XCTAssertNotEqual(value, "common.done", "common.done is a raw key in \(locale)")
        }
    }

    /// The possible-duplicate badge carries meaning that color alone must never
    /// carry, so its TEXT has to be real in every locale — a raw key or an empty
    /// string would silently demote the badge to a hue-only signal for anyone who
    /// can't distinguish the amber.
    func test_duplicate_review_strings_are_real_in_all_locales() {
        let keys = [
            "transactions.duplicate.badge",
            "duplicates.banner.title",
            "duplicates.banner.subtitle",
            "duplicates.review.title",
            "duplicates.review.keep",
            "duplicates.review.delete",
            "duplicates.review.keep_all",
            "duplicates.review.delete_all",
        ]
        for locale in locales {
            guard let dict = strings(for: locale) else {
                XCTFail("Missing locale: \(locale)")
                continue
            }
            for key in keys {
                let value = dict[key]
                XCTAssertNotNil(value, "\(key) missing in \(locale)")
                XCTAssertFalse((value ?? "").isEmpty, "\(key) empty in \(locale)")
                XCTAssertNotEqual(value, key, "\(key) is a raw key in \(locale)")
            }
        }
    }

    // MARK: - Code ↔ strings completeness (catches the Round 10 raw-key leak)

    /// The parity tests above only compare locales to *each other*. They cannot
    /// catch a key that is referenced in code but missing from **every** locale —
    /// which is exactly how `tx_detail.*` shipped as raw keys. This test scans the
    /// Swift source for localization call-sites and asserts every referenced key
    /// exists in the EN master `.strings`.
    func testNoMissingLocalizationKeys() throws {
        let sourceDir = URL(fileURLWithPath: #filePath)   // …/FinanceTrackerTests/LocaleCompletenessTests.swift
            .deletingLastPathComponent()                  // …/FinanceTrackerTests
            .deletingLastPathComponent()                  // …/ (repo root)
            .appendingPathComponent("FinanceTracker")     // …/FinanceTracker (app sources)

        let referenced = scanCodebaseForLocalizationKeys(in: sourceDir)
        XCTAssertFalse(referenced.isEmpty, "Scanner found no keys — path wrong? \(sourceDir.path)")

        let masterURL = sourceDir.appendingPathComponent("en.lproj/Localizable.strings")
        let master = parseStringsFile(try String(contentsOf: masterURL, encoding: .utf8))

        let missing = referenced.subtracting(master)
        XCTAssertTrue(missing.isEmpty,
            "Localization keys referenced in code but absent from en.lproj/Localizable.strings:\n" +
            missing.sorted().joined(separator: "\n"))
    }

    /// Stronger sibling of `testNoMissingLocalizationKeys`: every key referenced
    /// in code must exist in **every** shipping locale, not just the EN master.
    /// This is what would have caught the Bug 17 leak in non-EN locales too.
    func testAllLocalizedKeysExist() throws {
        let sourceDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FinanceTracker")

        let referenced = scanCodebaseForLocalizationKeys(in: sourceDir)
        XCTAssertFalse(referenced.isEmpty, "Scanner found no keys — path wrong? \(sourceDir.path)")

        for locale in locales {
            guard let dict = strings(for: locale) else {
                XCTFail("Missing locale: \(locale)")
                continue
            }
            let present = Set(dict.keys)
            let missing = referenced.subtracting(present)
            XCTAssertTrue(missing.isEmpty,
                "\(locale) is missing localization keys referenced in code:\n" +
                missing.sorted().joined(separator: "\n"))
        }
    }

    /// Extracts dotted localization keys from Swift localization call-sites.
    /// `systemImage:` / `systemName:` arguments are stripped first so SF Symbol
    /// names (e.g. "house.fill") are never mistaken for keys. Only the first
    /// string argument of a known localizing construct is considered, and only
    /// when it matches a dotted `a.b.c` key shape.
    private func scanCodebaseForLocalizationKeys(in directory: URL) -> Set<String> {
        // swiftlint:disable:next force_try
        let callSite = try! NSRegularExpression(pattern:
            #"(?:NSLocalizedString|String\(localized:|LocalizedStringKey|Text|Section|Button|Label|Toggle|Picker|row|navigationTitle|navigationBarTitle|confirmationDialog|alert|tabItem|header:\s*Text)\s*\(\s*"([^"]+)""#)
        // Codebase-specific helpers that take a localization key as a plain String
        // — these are how the add.error.* leak shipped (Bug 17): showErrorKey("…")
        // and fail(key: "…").
        let helperCallSite = try! NSRegularExpression(pattern:
            #"(?:showErrorKey\s*\(|fail\s*\(\s*key:)\s*"([^"]+)""#)
        // Bug 19: the Reset alert leaked raw keys because they flow through a
        // showInfo(titleKey:messageKey:) helper and an `infoMessageKey` @State
        // default — neither a recognized localizing construct nor a
        // showErrorKey/fail call, so the scanner above never saw them. Generalize
        // to the whole class: any argument label OR stored property whose name ends
        // in `Key` carrying a dotted-key string literal. The dotted-shape filter
        // (isDotted) below discards non-localization matches like
        // `forKey: "AppleLanguages"`. Covers titleKey:/messageKey:/nameKey:/
        // labelKey:/textKey: arguments and `saveErrorKey =` / `infoMessageKey:
        // String = …` assignments and comparisons.
        let keyTypedArg = try! NSRegularExpression(pattern:
            #"[A-Za-z_]*[Kk]ey\s*:\s*"([^"]+)""#)
        let keyTypedAssign = try! NSRegularExpression(pattern:
            #"[A-Za-z_]*[Kk]ey[^"\n]*=\s*"([^"]+)""#)
        let symbolArg = try! NSRegularExpression(pattern: #"system(?:Image|Name):\s*"[^"]+""#)
        let dotted = try! NSRegularExpression(pattern: #"^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$"#)

        func isDotted(_ s: String) -> Bool {
            dotted.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
        }

        var keys = Set<String>()
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: directory, includingPropertiesForKeys: nil) else { return keys }
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard var src = try? String(contentsOf: url, encoding: .utf8) else { continue }
            // Neutralize SF Symbol args so they can't be read as keys.
            src = symbolArg.stringByReplacingMatches(
                in: src, range: NSRange(src.startIndex..., in: src), withTemplate: "systemImage: SYMBOL")
            let range = NSRange(src.startIndex..., in: src)
            for regex in [callSite, helperCallSite, keyTypedArg, keyTypedAssign] {
                regex.enumerateMatches(in: src, range: range) { match, _, _ in
                    guard let m = match, let r = Range(m.range(at: 1), in: src) else { return }
                    let key = String(src[r])
                    if isDotted(key) { keys.insert(key) }
                }
            }
        }
        return keys
    }

    /// Parses the keys out of a `.strings` file (`"key" = "value";`).
    private func parseStringsFile(_ content: String) -> Set<String> {
        // swiftlint:disable:next force_try
        let keyLine = try! NSRegularExpression(pattern: #"^\s*"([^"]+)"\s*="#, options: [.anchorsMatchLines])
        var keys = Set<String>()
        let range = NSRange(content.startIndex..., in: content)
        keyLine.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let m = match, let r = Range(m.range(at: 1), in: content) else { return }
            keys.insert(String(content[r]))
        }
        return keys
    }

    func test_supported_language_enum_has_exactly_six_cases() {
        // System + EN + RU + ES + pt + uk — anything else means a locale drifted.
        XCTAssertEqual(SupportedLanguage.allCases.count, 6)
        XCTAssertEqual(Set(SupportedLanguage.allCases.map(\.id)),
                       ["system", "en", "ru", "es", "pt", "uk"])
    }
}
