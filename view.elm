module View exposing (view)

import UI
import UI as Msg exposing (Msg)
import UI as PlayerAction exposing (PlayerAction)
import Style           exposing (..)
import Domain          exposing (..)
import Html            exposing (..)
import Html.Events     exposing (..)
import Html.Attributes exposing (..)
import Util            exposing (..)
import Array           exposing (..)
import Time            exposing (..)

onClickDo: PlayerAction -> Attribute Msg
onClickDo action = onClick (UI.PlayerAction action)

cardContent : Card -> List (Html Msg) -> List (Html Msg)
cardContent card buttons =
    List.append buttons [ text card.name, priceMeterView card.cardType ]

viewCard : Card -> Html Msg
viewCard card =
  div [ class "card" ]
      (cardContent card [])

fieldView : Player -> Index -> Field -> Html Msg
fieldView player index field =
  let
    {amount, card} = field
    cardText = text (card.name ++ " (" ++ (toString amount) ++")")
    sellAmount = Domain.sellPrice amount card.cardType
    sellButton = button [ onClickDo (PlayerAction.SellField player index) ] [ text ("Sell $" ++ (toString sellAmount)) ]
  in
    div [ class "card" ] [ cardText, sellButton, priceMeterView card.cardType ]

tradeButtonsView players player cardIndex =
  let
    tradeForPlayer toPlayer =
      button [ class "tradeButton",
               onClickDo (PlayerAction.Trade player cardIndex toPlayer) ]
             [ text ("to " ++ toPlayer.nick) ]
  in
    List.map tradeForPlayer players

tradeFromHandButtonsView players player cardIndex =
  let
    tradeForPlayer toPlayer =
      button [ class "tradeButton",
               onClickDo (PlayerAction.TradeFromHand player cardIndex toPlayer) ]
             [ text ("to " ++ toPlayer.nick) ]
  in
    List.map tradeForPlayer players

plantButton player =
  button [ class "plantButton",
           onClickDo (PlayerAction.PlantFromHand player) ]
         [ text ("Plant") ]

plantSideButton player index =
  button [ class "plantButton",
           onClickDo (PlayerAction.PlantFromSide player index) ]
         [ text ("Plant") ]

keepButton player index =
  button [ onClickDo (PlayerAction.KeepFromTrade player index) ]
         [ text ("Keep") ]

viewTopMostHandCard players player card =
  let
    cardIndex = 0
    tradeButtons = tradeFromHandButtonsView players player cardIndex
    buttons = (plantButton player) :: tradeButtons
  in
    div [ class "card" ] (cardContent card buttons)

amountToPriceView {amount, money} =
  div [ class "priceMapping" ]
      [ div [ class "coins" ]
            [ text (toString money) ],
        div [ class "meterLimit" ]
            [ text (toString amount)] ]

priceMeterView : CardType -> Html Msg
priceMeterView cardType =
  let
    meterList = Domain.priceMeterList cardType
    priceColumns = Array.map amountToPriceView meterList |> Array.toList
  in
    div [ class "priceMeter" ] priceColumns

viewHand : List Player -> Player -> List Card -> List (Html Msg)
viewHand players player hand =
  let
    topmost = List.head hand
    topmostView = mapMaybeToList (viewTopMostHandCard players player) topmost
    cardWithTrades cardIndex card =
      div [ class "card" ]
          (cardContent card (tradeFromHandButtonsView players player cardIndex))

    -- note: indexing contains the first hand so that the rest get correct hand index
    cardsUnderTopView = List.drop 1 (List.indexedMap cardWithTrades hand)
  in
    List.append topmostView cardsUnderTopView

sideView : List Player -> Player -> List Card -> List (Html Msg)
sideView players player side =
  let
    sideCardView index card =
      div [ class "card" ] (cardContent card [ plantSideButton player index ])
  in
    List.indexedMap sideCardView side

fieldsView : Player -> Array Field -> List (Html Msg)
fieldsView player fields =
  let fv index field = div [ class "field" ] [fieldView player index field]
  in Array.indexedMap fv fields |> Array.toList

tradeView : List Player -> Player -> List Card -> List (Html Msg)
tradeView players player trade =
  let
    tradeCardView index card =
      let
        tradeButtons = tradeButtonsView players player index
        keepBtn = keepButton player index
        tradeViewContent = cardContent card (keepBtn :: tradeButtons)
        iv = div [] [ text (toString index) ]
      in
        div [ class "card" ] (iv :: tradeViewContent)
  in
    List.indexedMap tradeCardView trade

playerView : List Player -> Player -> List (Html Msg)
playerView players player =
  let
    (o1, o2) = otherElements players (\(i, p)  -> p.nick == player.nick)
    otherPlayers = List.append o1 o2
  in [
    div [ class "player-info" ] [
      text ("Player: " ++ player.nick),
      span [ class "money" ] [ text ("Money: " ++ (toString player.money)) ]
    ],
    button [ onClickDo (PlayerAction.DrawCardsToTrade player) ] [ text "Draw cards for trade" ],
    button [ onClickDo (PlayerAction.DrawCardsToHand player) ] [ text "Draw cards to hand" ],
    div [ class "fields-and-hand" ] [
      div [ class "fields" ] (fieldsView player player.fields),
      div [ class "hand" ] (viewHand otherPlayers player (Array.toList player.hand))
    ],
    div [ class "trading"] [
      div [ class "trade" ] (tradeView otherPlayers player (Array.toList player.trade)),
      div [ class "side" ] (sideView otherPlayers player (Array.toList player.side)) ]
    ]

timeView : Maybe Time -> Time -> Html Msg
timeView startTime currentTime =
  let
    playTime = Maybe.withDefault 0 (Maybe.map (\start -> currentTime - start) startTime)
    timeInSeconds = Time.inSeconds playTime |> round |> toString
  in
    div [ class "time" ]
        [ text "Play time: ",
          span [ class "seconds" ] [ text <| timeInSeconds ],
          text " seconds." ]

view : Model -> Html Msg
view model =
  let
    playerList = Array.toList model.players
    deckView = div [ class "deck" ] (List.map viewCard (Array.toList model.deck))
    discardView = div [ class "discard" ] (List.map viewCard (Array.toList model.discard))
    playersView = List.concatMap (playerView playerList) playerList
    playTimeView = timeView model.startTime model.currentTime
    gameView = stylesheet :: playTimeView :: deckView :: discardView :: playersView
  in
    div [ class "game-view" ] gameView
