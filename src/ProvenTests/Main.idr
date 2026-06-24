-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.Main

import ProvenTests.Runners
import System

-- =============================================================================
-- MAIN ENTRY POINT
-- =============================================================================
-- Thin driver over the library. The per-category test suites live under
-- tests/TypeSafeTests and are not yet wired into a build target; run them via a
-- dedicated test package once that exists (see docs/STATE-OF-THINGS.adoc).

--/ Main entry point for the Proven-Tests framework.
--/ Exits non-zero if any suite fails, so CI gates on the result.
main : IO ()
main = do
  ok <- runComprehensiveSuite
  if ok then pure () else exitFailure
