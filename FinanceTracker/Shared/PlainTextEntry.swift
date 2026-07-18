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
//  meaning, rather than leaving the inference to run. It is the only supported
//  API for this: UITextContentType has no "none" case, and there is no
//  "disable AutoFill" switch.
//
//  Deliberately NOT used here, despite being the popular answer online:
//    * `.oneTimeCode` — does hide the Passwords key, but opts the field INTO
//      SMS security-code suggestions. Strictly worse than the symptom.
//    * `UITextContentType("")` / a dummy string — relies on unspecified
//      behaviour of an invalid raw value, and is the kind of native-behaviour
//      workaround App Review §2.5.9 exists to discourage.
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
