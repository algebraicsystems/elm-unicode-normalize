port module Main exposing (main)

import Platform
import Unicode.Normalize exposing (normalize, Form(..))

port receiveInputString : (String -> msg) -> Sub msg
port sendNormalizedString : String -> Cmd msg

main : Program () Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }

type alias Model = ()

type Msg
    = GotInputString String

init : () -> ( Model, Cmd Msg )
init _ =
    ( (), Cmd.none )

subscriptions : Model -> Sub Msg
subscriptions =
    always (receiveInputString GotInputString)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotInputString inputString ->
            ( model, sendNormalizedString (normalize NFC inputString) )
