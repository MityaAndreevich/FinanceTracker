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
}
