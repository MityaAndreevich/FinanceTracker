//
//  PlainTextEntry.swift
//  FinanceTracker
//
//  One place to declare "this field has no credential or contact semantics".
//
//  The app has no accounts and no login, so no field should ever offer Passwords
//  or Contacts in the QuickType bar — on a privacy-positioned app that reads
//  careless. Every TextField shipped without a `textContentType`, which leaves
//  iOS to GUESS from heuristics (field position, neighbouring fields, label
//  text), and it guesses "credential" often enough to surface the key.
//
//  `.textContentType(nil)` states explicitly that the field carries no semantic
//  meaning, rather than leaving the inference to run. UITextContentType has no
//  "none" case and there is no "disable AutoFill" switch, so this is the lever
//  for the INFERENCE — and only for the inference.
//
//  SCOPE — what this does NOT do (device-verified, 2026-07-18):
//  It does not remove the AutoFill edit menu. Long-pressing a field still offers
//  Contact / Passwords / Credit Card / Scan Text, and that is EXPECTED: the menu
//  is a separate mechanism from type inference. `textContentType` governs what
//  iOS guesses the field means; the menu is a system affordance offered on
//  generic text fields whatever that guess is. Setting one was never going to
//  suppress the other.
//
//  We accept the menu as system default. The one public-API route that looked
//  viable — removing `UIMenuAutoFill` via `UIMenuBuilder.remove(menu:)` in a
//  `UIResponder.buildMenu(with:)` override on the app delegate — was tried and
//  FAILED ON DEVICE: the override never fires, because the context menu system
//  does not route the build through the app delegate for a SwiftUI TextField.
//  Don't re-attempt it from the delegate; it compiles, ships, and does nothing.
//
//  Deliberately NOT used here, despite being the popular answer online:
//    * `.oneTimeCode` — does hide the Passwords key, but opts the field INTO
//      SMS security-code suggestions. Strictly worse than the symptom.
//    * `UITextContentType("")` / a dummy string — relies on unspecified
//      behaviour of an invalid raw value, and is the kind of native-behaviour
//      workaround App Review §2.5.9 exists to discourage.
//    * A hidden dummy secure field to soak up the AutoFill association — a
//      layout-affecting hack for a cosmetic symptom.
//
//  Autocorrect and capitalization are left alone: this modifier is about
//  AutoFill semantics only, so a note field keeps behaving like a note field.
//

import SwiftUI

extension View {
    /// Marks a text field as ordinary content with no credential or contact
    /// meaning, so iOS stops inferring one. Apply to every free-text field the
    /// app owns — applying it in one shared place is what keeps a newly added
    /// field from silently regressing to the guessing behaviour.
    func plainTextEntry() -> some View {
        textContentType(nil)
    }
}
