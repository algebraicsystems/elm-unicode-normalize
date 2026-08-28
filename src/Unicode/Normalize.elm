module Unicode.Normalize exposing
    ( Form(..)
    , normalize
    )

{-| Unicode normalization.

There are multiple ways to normalize a string, referred to as _Normalization
Forms_. Which one you want depends on what you want to do with the string, but
the most common is `NFC`, which preserves the exact visual appearance of the
string. If you don't care about the details, just use `normalize NFC`.

    import Unicode.Normalize exposing (Form(..), normalize)

    normalize NFC "é"
    --> "é"

    normalize NFC (String.fromList [ 'ᄉ', 'ᅥ', 'ᆼ' ])
    --> "성"


# Normalization Forms

@docs Form


# Normalize a String

@docs normalize

-}

import Unicode.Normalize.Internal
    exposing
        ( canonicalComposition
        , canonicalDecomposition
        , combiningClass
        , compatibleDecomposition
        )



-- PUBLIC API


{-| The different ways to normalize a string.

  - **NFC**: Canonical decomposition followed by canonical composition.
  - **NFD**: Canonical decomposition without recomposition.
  - **NFKC**: Compatibility decomposition followed by canonical composition.
  - **NFKD**: Compatibility decomposition without recomposition.

_Canonical decomposition_ splits single characters into sequences of equivalent
combining characters. _Compatibility decomposition_ extends canonical
decomposition by also replacing variants of the same logical character (such as
replacing ¼ with 1/4).

_Canonical composition_ undoes the process of canonical decomposition,
combining sequences into single characters wherever possible.

For example, the character "ñ" can be represented as a single code point
(`U+00F1`) or as two code points ("n" followed by a combining tilde,
`U+006E U+0303`). The normalization forms handle this differently:

    -- NFC composes into a single character
    normalize NFC "ñ"  -- (n + combining tilde)
    --> "ñ"            -- (single ñ)

    -- NFD decomposes into base + combining character
    normalize NFD "ñ"  -- (single ñ)
    --> "ñ"            -- (n + combining tilde)

The compatibility forms also replace visual variants:

    -- NFKC replaces ﬁ ligature with "fi" and composes
    normalize NFKC "ﬁñ"
    --> "fiñ"

    -- NFKD replaces ﬁ ligature with "fi" and decomposes
    normalize NFKD "ﬁñ"
    --> "fiñ"

-}
type Form
    = NFC
    | NFD
    | NFKC
    | NFKD


{-| Normalize a string to a particular Normalization Form.

    -- Two equivalent representations of "é" become identical after NFC
    normalize NFC "é" == normalize NFC "é"
    --> True

    -- ASCII strings are unaffected
    normalize NFC "hello"
    --> "hello"

    -- Compatibility normalization replaces special forms
    normalize NFKC "①②③"
    --> "123"

    normalize NFKC "ﬃ"
    --> "ffi"

-}
normalize : Form -> String -> String
normalize form =
    case form of
        NFC ->
            toCodePoints
                >> canonicalDecompose
                >> canonicalOrder
                >> canonicalCompose
                >> fromCodePoints

        NFD ->
            toCodePoints
                >> canonicalDecompose
                >> canonicalOrder
                >> fromCodePoints

        NFKC ->
            toCodePoints
                >> compatibleDecompose
                >> canonicalOrder
                >> canonicalCompose
                >> fromCodePoints

        NFKD ->
            toCodePoints
                >> compatibleDecompose
                >> canonicalOrder
                >> fromCodePoints


toCodePoints : String -> List Int
toCodePoints string =
    List.map Char.toCode (String.toList string)


fromCodePoints : List Int -> String
fromCodePoints codes =
    String.fromList (List.map Char.fromCode codes)



-- DECOMPOSITION


canonicalDecompose : List Int -> List Int
canonicalDecompose =
    let
        decompose : Int -> List Int
        decompose code =
            Nothing
                |> tryMaybe (\() -> decomposeHangulSyllable code)
                |> tryMaybe (\() -> canonicalDecomposition code)
                |> Maybe.withDefault [ code ]
    in
    List.concatMap decompose


compatibleDecompose : List Int -> List Int
compatibleDecompose =
    let
        decompose : Int -> List Int
        decompose code =
            Nothing
                |> tryMaybe (\() -> decomposeHangulSyllable code)
                |> tryMaybe (\() -> compatibleDecomposition code)
                |> tryMaybe (\() -> canonicalDecomposition code)
                |> Maybe.withDefault [ code ]
    in
    List.concatMap decompose



-- ORDERING


canonicalOrder : List Int -> List Int
canonicalOrder chars =
    let
        step : Int -> ( List Int, List Int ) -> ( List Int, List Int )
        step code ( currentRun, ordered ) =
            if combiningClass code == 0 then
                ( [], code :: (List.sortBy combiningClass currentRun ++ ordered) )

            else
                ( code :: currentRun, ordered )

        ( finalRun, finalResult ) =
            List.foldr step ( [], [] ) chars
    in
    List.sortBy combiningClass finalRun ++ finalResult



-- RECOMPOSITION


canonicalCompose : List Int -> List Int
canonicalCompose codes =
    case codes of
        [] ->
            []

        code :: rest ->
            canonicalComposeWithBlockers code [] rest


canonicalComposeWithBlockers : Int -> List Int -> List Int -> List Int
canonicalComposeWithBlockers starter blockers codes =
    case codes of
        [] ->
            starter :: List.reverse blockers

        code :: rest ->
            let
                currentClass : Int
                currentClass =
                    combiningClass code

                canCompose : Bool
                canCompose =
                    List.all
                        (\blocker -> combiningClass blocker < currentClass)
                        blockers
            in
            case ( canCompose, canonicalOrHangulComposition starter code ) of
                ( True, Just composed ) ->
                    canonicalComposeWithBlockers composed blockers rest

                _ ->
                    if currentClass == 0 then
                        starter
                            :: List.reverse blockers
                            ++ canonicalComposeWithBlockers code [] rest

                    else
                        canonicalComposeWithBlockers starter (code :: blockers) rest


canonicalOrHangulComposition : Int -> Int -> Maybe Int
canonicalOrHangulComposition starter code =
    Nothing
        |> tryMaybe (\() -> composeHangulSyllable1 starter code)
        |> tryMaybe (\() -> composeHangulSyllable2 starter code)
        |> tryMaybe (\() -> canonicalComposition starter code)



-- HANGUL


syllableBase : Int
syllableBase =
    0xAC00


leadingBase : Int
leadingBase =
    0x1100


vowelBase : Int
vowelBase =
    0x1161


trailingBase : Int
trailingBase =
    0x11A7


leadingCount : Int
leadingCount =
    19


vowelCount : Int
vowelCount =
    21


trailingCount : Int
trailingCount =
    28


vowelTrailingCount : Int
vowelTrailingCount =
    vowelCount * trailingCount


syllableCount : Int
syllableCount =
    leadingCount * vowelTrailingCount


decomposeHangulSyllable : Int -> Maybe (List Int)
decomposeHangulSyllable code =
    let
        index : Int
        index =
            code - syllableBase
    in
    if index >= 0 && index < syllableCount then
        let
            leadingIndex : Int
            leadingIndex =
                leadingBase + (index // vowelTrailingCount)

            vowelIndex : Int
            vowelIndex =
                vowelBase + (modBy vowelTrailingCount index // trailingCount)

            trailingIndex : Int
            trailingIndex =
                modBy trailingCount index
        in
        if trailingIndex == 0 then
            Just [ leadingIndex, vowelIndex ]

        else
            Just [ leadingIndex, vowelIndex, trailingBase + trailingIndex ]

    else
        Nothing


composeHangulSyllable1 : Int -> Int -> Maybe Int
composeHangulSyllable1 leading vowel =
    let
        leadingIndex : Int
        leadingIndex =
            leading - leadingBase

        vowelIndex : Int
        vowelIndex =
            vowel - vowelBase
    in
    if
        (leadingIndex >= 0)
            && (leadingIndex < leadingCount)
            && (vowelIndex >= 0)
            && (vowelIndex < vowelCount)
    then
        Just (syllableBase + ((leadingIndex * vowelCount) + vowelIndex) * trailingCount)

    else
        Nothing


composeHangulSyllable2 : Int -> Int -> Maybe Int
composeHangulSyllable2 syllable trailing =
    let
        syllableIndex : Int
        syllableIndex =
            syllable - syllableBase

        trailingIndex : Int
        trailingIndex =
            trailing - trailingBase
    in
    if
        (syllableIndex >= 0)
            && (syllableIndex < syllableCount)
            && (modBy trailingCount syllableIndex == 0)
            && (trailingIndex >= 0)
            && (trailingIndex < trailingCount)
    then
        Just (syllable + trailingIndex)

    else
        Nothing



-- HELPERS


tryMaybe : (() -> Maybe a) -> Maybe a -> Maybe a
tryMaybe closure maybe =
    case maybe of
        Just value ->
            Just value

        Nothing ->
            closure ()
