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
            withCodePoints (canonicalDecompose >> canonicalOrder >> canonicalCompose)

        NFD ->
            withCodePoints (canonicalDecompose >> canonicalOrder)

        NFKC ->
            withCodePoints (compatibleDecompose >> canonicalOrder >> canonicalCompose)

        NFKD ->
            withCodePoints (compatibleDecompose >> canonicalOrder)


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
            if isHangulSyllable code then
                decomposeHangulSyllable code

            else
                canonicalDecomposition code
    in
    List.concatMap decompose


compatibleDecompose : List Int -> List Int
compatibleDecompose =
    let
        decompose code =
            if isHangulSyllable code then
                decomposeHangulSyllable code

            else
                compatibleDecomposition code
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
            case ( canCompose, canonicalComposition starter code ) of
                ( True, Just composed ) ->
                    canonicalComposeWithBlockers composed blockers rest

                _ ->
                    if currentClass == 0 then
                        starter
                            :: List.reverse blockers
                            ++ canonicalComposeWithBlockers code [] rest

                    else
                        canonicalComposeWithBlockers starter (code :: blockers) rest



-- HANGUL


hangulSBase : Int
hangulSBase =
    0xAC00


hangulLBase : Int
hangulLBase =
    0x1100


hangulVBase : Int
hangulVBase =
    0x1161


hangulTBase : Int
hangulTBase =
    0x11A7


hangulLCount : Int
hangulLCount =
    19


hangulVCount : Int
hangulVCount =
    21


hangulTCount : Int
hangulTCount =
    28


hangulNCount : Int
hangulNCount =
    hangulVCount * hangulTCount


hangulSCount : Int
hangulSCount =
    hangulLCount * hangulNCount


isHangulSyllable : Int -> Bool
isHangulSyllable code =
    let
        index =
            code - hangulSBase
    in
    index >= 0 && index < hangulSCount


decomposeHangulSyllable : Int -> List Int
decomposeHangulSyllable code =
    let
        index =
            code - hangulSBase

        leading =
            hangulLBase + (index // hangulNCount)

        vowel =
            hangulVBase + (modBy hangulNCount index // hangulTCount)

        trailing =
            modBy hangulTCount index
    in
    if trailing == 0 then
        [ leading, vowel ]

    else
        [ leading, vowel, trailing ]
