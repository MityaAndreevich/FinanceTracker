//
//  NewCategoryViewModelTests.swift
//  FinanceTrackerTests
//
//  Bug 16: adding a category with the "car" icon crashed the app. These tests
//  pin the validated build path — bad input returns an error, never traps.
//

import Foundation
import Testing
@testable import FinanceTracker

@Suite("NewCategoryViewModel")
@MainActor
struct NewCategoryViewModelTests {

    @Test func test_validIcon_succeeds_andKeepsIcon() {
        let result = NewCategoryViewModel.makeCategory(
            name: "Машина", kindRaw: "expense", icon: "car", order: 3
        )
        guard case .success(let category) = result else {
            Issue.record("expected success, got \(result)"); return
        }
        #expect(category.icon == "car")
        #expect(category.nameCustom == "Машина")
        #expect(category.kindRaw == "expense")
        #expect(category.order == 3)
    }

    @Test func test_emptyIcon_succeeds_withNilIcon() {
        let result = NewCategoryViewModel.makeCategory(
            name: "Rent", kindRaw: "expense", icon: "   ", order: 0
        )
        guard case .success(let category) = result else {
            Issue.record("expected success, got \(result)"); return
        }
        #expect(category.icon == nil)
    }

    @Test func test_blankName_returnsEmptyNameError_notCrash() {
        let result = NewCategoryViewModel.makeCategory(
            name: "   ", kindRaw: "expense", icon: "car", order: 0
        )
        guard case .failure(let error) = result else {
            Issue.record("expected failure, got \(result)"); return
        }
        #expect(error == .emptyName)
    }

    @Test func test_unrenderableIcon_returnsInvalidIconError_notCrash() {
        let bogus = "this.is.not.a.real.sf.symbol.name.\(UUID().uuidString)"
        let result = NewCategoryViewModel.makeCategory(
            name: "Car", kindRaw: "expense", icon: bogus, order: 0
        )
        guard case .failure(let error) = result else {
            Issue.record("expected failure, got \(result)"); return
        }
        #expect(error == .invalidIcon(bogus))
    }

    @Test func test_nameIsTrimmed() {
        let result = NewCategoryViewModel.makeCategory(
            name: "  Groceries  ", kindRaw: "expense", icon: nil, order: 1
        )
        guard case .success(let category) = result else {
            Issue.record("expected success, got \(result)"); return
        }
        #expect(category.name == "Groceries")
        #expect(category.nameCustom == "Groceries")
    }

    // MARK: - Bug 18: duplicate name is rejected, never silently inserted

    @Test func testSaveDuplicateName_returnsError_doesNotInsert() {
        let existing = Category(
            name: "Машина", kindRaw: "expense", icon: nil, order: 0,
            nameKey: nil, nameCustom: "Машина"
        )
        // Same name (case-insensitive, with surrounding space) and same kind.
        let result = NewCategoryViewModel.makeCategory(
            name: "  машина ", kindRaw: "expense", icon: "car", order: 1,
            existing: [existing]
        )
        guard case .failure(let error) = result else {
            Issue.record("expected duplicate failure, got \(result)"); return
        }
        #expect(error == .duplicateName)
    }

    @Test func testDuplicateName_differentKind_isAllowed() {
        // "Bonus" as an expense must not block an income "Bonus".
        let existing = Category(
            name: "Bonus", kindRaw: "expense", icon: nil, order: 0,
            nameKey: nil, nameCustom: "Bonus"
        )
        let result = NewCategoryViewModel.makeCategory(
            name: "Bonus", kindRaw: "income", icon: nil, order: 0,
            existing: [existing]
        )
        guard case .success = result else {
            Issue.record("expected success for different kind, got \(result)"); return
        }
    }

    // Sprint B patch (device test #5): the inline category-create flows (Add
    // Transaction, Quick Entry picker) and Settings all share this gate. A
    // .duplicateName result is what drives AddCategorySheet to show the alert and
    // to NOT call onCreate — so the caller never selects/commits a half-created
    // category and the transaction isn't filed against one. These pin that gate
    // per entry point (the SwiftUI plumbing itself is covered on-device).

    @Test func testAddTransactionInlineCategoryCreate_duplicateName_showsAlertAndAbortsSave() {
        let existing = Category(
            name: "Тест", kindRaw: "expense", icon: nil, order: 0,
            nameKey: nil, nameCustom: "Тест"
        )
        let result = NewCategoryViewModel.makeCategory(
            name: "Тест", kindRaw: "expense", icon: "tag", order: 1,
            existing: [existing]
        )
        guard case .failure(.duplicateName) = result else {
            Issue.record("inline create must report .duplicateName, got \(result)"); return
        }
    }

    @Test func testQuickEntryInlineCategoryCreate_duplicateName_showsAlertAndAbortsSave() {
        // Quick Entry picker defaults to the parsed transaction's kind; a same-kind
        // collision must gate identically to the Settings/Add-Transaction paths.
        let existing = Category(
            name: "Кафе", kindRaw: "expense", icon: nil, order: 0,
            nameKey: nil, nameCustom: "Кафе"
        )
        let result = NewCategoryViewModel.makeCategory(
            name: "  кафе ", kindRaw: "expense", icon: nil, order: 2,
            existing: [existing]
        )
        guard case .failure(.duplicateName) = result else {
            Issue.record("Quick Entry inline create must report .duplicateName, got \(result)"); return
        }
    }

    @Test func testRenameAfterDuplicate_savesSuccessfully() {
        let existing = Category(
            name: "Машина", kindRaw: "expense", icon: nil, order: 0,
            nameKey: nil, nameCustom: "Машина"
        )
        // The user renames after the collision — the icon/type they already
        // picked are preserved and the save now succeeds.
        let result = NewCategoryViewModel.makeCategory(
            name: "Машина 2", kindRaw: "expense", icon: "car", order: 1,
            existing: [existing]
        )
        guard case .success(let category) = result else {
            Issue.record("expected success after rename, got \(result)"); return
        }
        #expect(category.nameCustom == "Машина 2")
        #expect(category.icon == "car")
        #expect(category.kindRaw == "expense")
    }
}
