module Unicode.Normalize exposing
    ( normalize
    , Form(..), normalizeForm
    )

{-| Get a Unicode Normalization Form of a string.

There are multiple ways to normalize a string, referred to as _Normalization
Forms_. Which one you want depends on what you want to do with the string, but
the most common is `NFC`, which preserves the exact visual appearance of the
string. If you don't care about the details, just use the `normalize` function.


# Default

@docs normalize


# Normalization Forms

@docs Form, normalizeForm

-}

import Unicode.Normalize.Internal
    exposing
        ( canonicalComposition
        , canonicalDecomposition
        , combiningClass
        , compatibleDecomposition
        )



-- PUBLIC API


{-| Get the NFC normalization of a string.
-}
normalize : String -> String
normalize =
    normalizeForm NFC


{-| The different ways to normalize a string.

  - **NFC**: Canonical decomposition followed by canonical composition.
  - **NFD**: Canonical decomposition without recomposition.
  - **NFKC**: Compatibility decomposition followed by canonical composition.
  - **NFKD**: Compatibility decomposition without recomposition.

-}
type Form
    = NFC
    | NFD
    | NFKC
    | NFKD


{-| Normalize a string using a particular Normalization Form.
-}
normalizeForm : Form -> String -> String
normalizeForm form =
    case form of
        NFC ->
            withCodePoints
                (canonicalDecompose >> canonicalOrder >> canonicalCompose)

        NFD ->
            withCodePoints
                (canonicalDecompose >> canonicalOrder)

        NFKC ->
            withCodePoints
                (compatibleDecompose >> canonicalOrder >> canonicalCompose)

        NFKD ->
            withCodePoints
                (compatibleDecompose >> canonicalOrder)


withCodePoints : (List Int -> List Int) -> String -> String
withCodePoints f =
    toCodePoints >> f >> fromCodePoints


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
        decompose code =
            Nothing
                |> tryMaybe (\() -> decomposeHangulSyllable code)
                |> tryMaybe (\() -> compatibleDecomposition code)
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
canonicalOrHangulComposition =
    tryCompositions
        [ composeHangulSyllable1
        , composeHangulSyllable2
        , canonicalComposition
        ]


tryCompositions : List (Int -> Int -> Maybe Int) -> Int -> Int -> Maybe Int
tryCompositions compositions starter code =
    case compositions of
        composition :: rest ->
            case composition starter code of
                Just composed ->
                    Just composed

                Nothing ->
                    tryCompositions rest starter code

        [] ->
            Nothing



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
            leading : Int
            leading =
                leadingBase + (index // vowelTrailingCount)

            vowel : Int
            vowel =
                vowelBase + (modBy vowelTrailingCount index // trailingCount)

            trailing : Int
            trailing =
                modBy trailingCount index
        in
        if trailing == 0 then
            Just [ leading, vowel ]

        else
            Just [ leading, vowel, trailing ]

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
            && (modBy syllableIndex trailingCount == 0)
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
