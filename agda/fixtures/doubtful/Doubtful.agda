-- SPDX-License-Identifier: MPL-2.0
-- NEGATIVE CONTROL for the doubt check: type-checks WITHOUT --safe, but uses a
-- postulate, TERMINATING pragma and type-in-type. Must be flagged.
{-# OPTIONS --cubical-compatible #-}
module Doubtful where

postulate Magic : Set

{-# TERMINATING #-}
loop : Magic → Magic
loop x = loop x
