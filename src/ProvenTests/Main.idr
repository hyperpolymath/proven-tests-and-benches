-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.Main

import ProvenTests.Runners

-- =============================================================================
-- MAIN ENTRY POINT
-- =============================================================================
-- Thin driver over the library. The per-category test suites live under
-- tests/TypeSafeTests and are not yet wired into a build target; run them via a
-- dedicated test package once that exists (see docs/STATE-OF-THINGS.adoc).

--/ Main entry point for the Proven-Tests framework
main : IO ()
main = runComprehensiveSuite
