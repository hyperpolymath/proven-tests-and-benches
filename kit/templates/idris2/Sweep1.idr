-- SPDX-License-Identifier: MPL-2.0
-- Sweep-1 template for Idris2 (0.7.0): UT, SMK, BLD, P2P. ADAPT: replace parseKv.
-- Build+run: cp sweep1.ipkg.template sweep1.ipkg && idris2 --build sweep1.ipkg && ./build/exec/sweep1   (exit 1 on any failure)
-- NOT EXECUTED in the foundation container (no idris2).
module Sweep1

import Data.List
import Data.String
import System

%default total

parseKv : String -> Maybe (String, String)
parseKv s = case break (== '=') (unpack s) of
  (_, []) => Nothing
  (k, _ :: v) => let key = trim (pack k) in
                 if key == "" then Nothing else Just (key, pack v)

-- a Bool test per case; the list is checked, an empty list is a failure (DOG-01)
cases : List (String, Bool)
cases =
  [ ("UT splits on first equals", parseKv "a=b=c" == Just ("a", "b=c"))
  , ("UT no separator",           parseKv "kv" == Nothing)
  , ("UT empty key",              parseKv " =v" == Nothing)
  , ("SMK entry point answers",   isJust (parseKv "k=v"))
  , ("P2P encode/decode seam",    parseKv ("name" ++ "=" ++ "x") == Just ("name", "x"))
  ]

-- UT/P2P as TYPES: a proof is a stronger test than a witness (Actually-Proven tier)
utProof : parseKv "k=v" = Just ("k", "v")
utProof = Refl

main : IO ()
main = do
  let bad = filter (not . snd) cases
  traverse_ (\(n, _) => putStrLn ("FAIL " ++ n)) bad
  when (null cases) $ putStrLn "NO CASES RAN" >> exitWith (ExitFailure 2)
  if null bad then putStrLn (show (length cases) ++ " passed") else exitWith (ExitFailure 1)
