//
//  ScaleTestGate.swift
//  FinanceTrackerTests
//
//  The bulk-delete SCALE measurements (16k-row stores, 290–689 s each, the
//  unit phase's 13.9 GB swap peak on 2026-10-12) are benchmarks. They run on
//  demand via scripts/run-scale-tests.sh, which sets TEST_RUNNER_RUN_SCALE_TESTS=1;
//  xcodebuild strips the TEST_RUNNER_ prefix and hands RUN_SCALE_TESTS=1 to the
//  test process (`man xcodebuild`, "TEST_RUNNER_<VAR>").
//
//  In the default run they are DISABLED, not deleted: Swift Testing reports a
//  disabled test as skipped, so run-tests.sh's executed+skipped total is
//  unchanged by the gate.
//
//  Their correctness half stays in the default gate: BulkDeleteCorrectnessTests.
//  Any release touching deletion, purge or reset needs a green run-scale-tests.sh
//  on the archived commit (ARCHITECTURE.md, release section).
//

import Foundation
import Testing

enum ScaleTestGate {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_SCALE_TESTS"] == "1"
    }
}

extension Trait where Self == ConditionTrait {
    /// `.scaleMeasurement` — runs only under scripts/run-scale-tests.sh.
    static var scaleMeasurement: Self {
        .enabled(if: ScaleTestGate.isEnabled,
                 "Scale benchmark: scripts/run-scale-tests.sh (RUN_SCALE_TESTS=1)")
    }
}
