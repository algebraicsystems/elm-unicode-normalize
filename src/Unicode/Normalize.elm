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


canonicalDecompose : List Int -> List Int
canonicalDecompose =
    List.concatMap canonicalDecomposition


compatibleDecompose : List Int -> List Int
compatibleDecompose =
    List.concatMap compatibleDecomposition


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


canonicalCompose : List Int -> List Int
canonicalCompose codes =
    case codes of
        [] ->
            []

        code :: rest ->
            canonicalComposeHelper code [] rest


canonicalComposeHelper : Int -> List Int -> List Int -> List Int
canonicalComposeHelper starter blockers codes =
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
                    canonicalComposeHelper composed blockers rest

                _ ->
                    if currentClass == 0 then
                        starter
                            :: List.reverse blockers
                            ++ canonicalComposeHelper code [] codes

                    else
                        canonicalComposeHelper starter (code :: blockers) rest
