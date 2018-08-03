module Main where

import Prelude (unit, Unit, bind, discard, mempty, pure, show, ($), (+), (-), (/), (<$>), (<*>), (<<<), (<>), map, void)
import Effect (Effect)
import Effect.Console (log)

import Data.Array
import Data.Traversable
import Data.Maybe (fromJust, maybe)
import Data.Set as S
import Data.Map as M
import Data.Int (toNumber)
import Math as Math

import FRP.Event (Event, subscribe, fold, makeEvent)
import FRP.Event.Keyboard (getKeyboard, Keyboard)
import FRP.Event.Mouse (getMouse, Mouse)
import FRP.Event.AnimationFrame (animationFrame)
import FRP.Behavior.Keyboard (keys)
import FRP.Behavior.Mouse (position)
import FRP.Behavior (ABehavior, sample_)
import Vector (Vector(..), getX, getY, origin, scale, vec)

import Color (Color, black, white, rgba)
import Graphics.Drawing (Shape, render, lineWidth, path, outlined, outlineColor, Point, Drawing, fillColor, filled, rectangle, text)
import Graphics.Drawing.Font (font, serif)
import Graphics.Canvas (getCanvasElementById, getContext2D, getCanvasWidth, getCanvasHeight)

import Partial.Unsafe (unsafePartial)
import Effect.Ref as Ref

import Network (runNetwork)

red :: Color
red = rgba 255 0 0 1.0

green :: Color
green = rgba 0 255 0 1.0

type InputDevices =
  { keyboard :: Keyboard
  , mouse :: Mouse
  }

type InputState =
  { mousePosition :: Vector
  , keysDown :: S.Set String
  }

type Player =
  { position :: Vector
  , aimAngle :: Number
  }

type State =
  { stageSize :: Vector
  , debug :: String
  , player :: Player
  }

initialState :: Vector -> State
initialState stageSize =
  { stageSize
  , debug: ""
  , player:
    { position: scale 0.5 stageSize
    , aimAngle: 0.0
    }
  }

background :: Vector -> Drawing
background (Vector {x: w, y: h}) = filled (fillColor black) (rectangle 0.0 0.0 w h)

toPoint :: Vector -> Point
toPoint (Vector {x, y}) = {x, y}

centeredRectangle :: Number -> Number -> Number -> Number -> Shape
centeredRectangle x y w h = rectangle (x - w / 2.0) (y - h / 2.0) w h

avatar :: Player -> Drawing
avatar player@({position: Vector {x, y}}) = body <> gun
  where
    gunStart = toPoint player.position
    gunEnd = toPoint (player.position + (scale 15.0 $ vec (Math.sin player.aimAngle) (Math.cos player.aimAngle)))
    gun = outlined (lineWidth 5.0 <> outlineColor green) (path [gunStart, gunEnd])
    body = filled (fillColor red) (centeredRectangle x y 20.0 20.0)

draw :: State -> Drawing
draw state = background (state.stageSize)
          <> avatar state.player
          <> text (font serif 12 mempty) 20.0 20.0 (fillColor white) state.debug
 
loop :: InputState -> State -> State
loop input state =
  state
    { debug = show aa
    , player = state.player
        { aimAngle = aa
        }
    }
  where
    rel = input.mousePosition - state.player.position
    aa = Math.atan2 (getX rel) (getY rel)

mousePositionToVector :: { x :: Int, y :: Int } -> Vector
mousePositionToVector {x, y} = vec (toNumber x) (toNumber y)

inputBehavior :: InputDevices -> ABehavior Event InputState
inputBehavior inputDevices = merge <$> position inputDevices.mouse <*> keys inputDevices.keyboard
  where
     merge m k =
      { mousePosition: maybe origin mousePositionToVector m
      , keysDown: k
      }

z :: InputDevices -> State -> Event State
z inputDevices state = fold loop (sample_ (inputBehavior inputDevices) animationFrame) state

okay :: M.Map Int (Unit -> Effect Unit) -> Effect (M.Map Int Unit)
okay m = sequence (map (\x-> do
           x unit
        ) m)

myEv :: Effect {event :: Event Unit, trigger :: Unit -> Effect Unit}
myEv = do
    listeners <- Ref.new M.empty
    event <- pure $ makeEvent \k-> do
      m <- Ref.read listeners
      id <- pure $ M.size m
      Ref.write (M.insert id k m) listeners
      pure $ do
        Ref.write (M.delete id m) listeners
    trigger <- pure \_-> do
      m <- Ref.read listeners
      void $ sequence (map (\k-> do
        k unit
      ) m)
    pure {event, trigger}

main :: Effect Unit
main = do
  runNetwork
  mc <- getCanvasElementById "canvas"
  let canvas = unsafePartial (fromJust mc)
  ctx <- getContext2D canvas
  w <- getCanvasWidth canvas
  h <- getCanvasHeight canvas
  state <- pure $ initialState (vec w h)
  keyboard <- getKeyboard
  mouse <- getMouse
  _ <- subscribe (z {keyboard, mouse} state) (render ctx <<< draw)
  log "end of main"
