module Unicode.Normalize exposing
    ( normalize
    , Form(..)
    , normalizeForm
    )

{-| Get a Unicode Normalization Form of a string.

There are multiple ways to normalize a string, referred to as *Normalization
Forms*. Which one you want depends on what you want to do with the string, but
the most common is `NFC`, which preserves the exact visual appearance of the
string. If you don't care about the details, just use the `normalize` function.

# Default
@docs normalize

# Normalization Forms
@docs Form, normalizeForm
-}


{-| Get the NFC normalization of a string. -}
normalize : String -> String
normalize =
    normalizeForm NFC


{-| The different ways to normalize a string. -}
type Form
    = NFC
    | NFD
    | NFKD
    | NFKC


{-| Normalize a string using a particular Normalization Form. -}
normalizeForm : Form -> String -> String
normalizeForm form string =
    Debug.todo "Implement normalizeForm"
