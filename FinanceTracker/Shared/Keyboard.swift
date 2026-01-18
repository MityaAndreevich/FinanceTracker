//
//  Keyboard.swift
//  FinanceTracker
//
//  Created by Dmitry Logachev (USA) on 17.01.2026.
//

import SwiftUI

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
#endif
