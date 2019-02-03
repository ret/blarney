{-# LANGUAGE NoDeriveAnyClass           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

{-|
Module      : Blarney.Module
Description : Blarney modules
Copyright   : (c) Matthew Naylor, 2019
License     : MIT
Maintainer  : mattfn@gmail.com
Stability   : experimental

We split the RTL monad into a Module monad and an Action monad, giving a
more familar HDL structure in which modules instantiate other modules,
and express behaviour through 'always' blocks containing actions.
Actions cannot instantiate modules.
-}
module Blarney.Module
  ( -- * Modules and actions
    Module(..), Action(..),

    -- * Lift actions to modules
    always,

    -- * Conditional actions
    when, whenR, switch, (-->),

    -- * Mutable variables
    Var(..),

    -- * Registers
    RTL.Reg(..), makeReg, makeRegU, makeDReg,

    -- * Wires
    RTL.Wire(..), makeWire, makeWireU,

    -- * Register files
    RegFile(..), makeRegFileInit, makeRegFile,

    -- * Other actions
    finish, RTL.display,

    -- * External inputs and outputs
    input, inputBV, output, outputBV,

    -- * Convert RTL to a netlist
    netlist
  ) where

-- Blarney imports
import Blarney.BV
import Blarney.Bit
import Blarney.Bits
import Blarney.FShow
import Blarney.Prelude
import Blarney.IfThenElse
import qualified Blarney.RTL as RTL
import qualified Blarney.JList as JL

-- Standard imports
import Prelude
import Data.IORef
import GHC.TypeLits
import Control.Monad.Fix
import Control.Monad hiding (when)

-- |A module is just a wrapper around the RTL monad
newtype Module a = M { runModule :: RTL.RTL a }
  deriving (Functor, Applicative, Monad, MonadFix)

-- |An action is just a wrapper around the RTL monad
newtype Action a = A { runAction :: RTL.RTL a }
  deriving (Functor, Applicative, Monad, MonadFix)

-- |Execute an action on every clock cycle
always :: Action a -> Module a
always a = M (runAction a)

-- |Conditional block over actions
when :: Bit 1 -> Action () -> Action ()
when c a = A (RTL.when c (runAction a))

-- |Conditional block over actions with return value
whenR :: Bit 1 -> Action a -> Action a
whenR c a = A (RTL.whenR c (runAction a))

-- |If-then-else statement for actions
ifThenElseAction :: Bit 1 -> Action () -> Action () -> Action ()
ifThenElseAction c a b = A (RTL.ifThenElseRTL c (runAction a) (runAction b))

-- |Overloaded if-then-else
instance IfThenElse (Bit 1) (Action ()) where
  ifThenElse = ifThenElseAction

-- |Switch statement over actions
switch :: Bits a => a -> [(a, Action ())] -> Action ()
switch subject alts =
  A (RTL.switch subject [(lhs, runAction rhs) | (lhs, rhs) <- alts])

-- |Operator for switch statement alternatives
infixl 0 -->
(-->) :: a -> Action () -> (a, Action ())
lhs --> rhs = (lhs, rhs)

-- |Mutable variables
infix 1 <==
class Var v where
  val :: Bits a => v a -> a
  (<==) :: Bits a => v a -> a -> Action ()

-- |Register read and write
instance Var RTL.Reg where
  val v = RTL.regVal v
  v <== x = A (RTL.writeReg v x)

-- |Wire read and write
instance Var RTL.Wire where
  val v = RTL.wireVal v
  v <== x = A (RTL.writeWire v x)

-- |Create register with initial value
makeReg :: Bits a => a -> Module (RTL.Reg a)
makeReg init = M (RTL.makeReg init)

-- |Create wire with don't care initial value
makeRegU :: Bits a => Module (RTL.Reg a)
makeRegU = M RTL.makeRegU

-- |Create wire with default value
makeWire :: Bits a => a -> Module (RTL.Wire a)
makeWire init = M (RTL.makeWire init)

-- |Create wire with don't care default value
makeWireU :: Bits a => Module (RTL.Wire a)
makeWireU = M RTL.makeWireU

-- |A DReg holds the assigned value only for one cycle.
-- At all other times, it has the given default value.
makeDReg :: Bits a => a -> Module (RTL.Reg a)
makeDReg defaultVal = M (RTL.makeDReg defaultVal)

-- |External input declaration
input :: KnownNat n => String -> Module (Bit n)
input str = M (RTL.input str)

-- |External input declaration (untyped)
inputBV :: String -> Width -> Module BV
inputBV str w = M (RTL.inputBV str w)

-- |External output declaration
output :: String -> Bit n -> Module ()
output str out = M (RTL.output str out)

-- |External output declaration (untyped)
outputBV :: String -> BV -> Module ()
outputBV str bv = M (RTL.outputBV str bv)

data RegFile a d =
  RegFile {
    (!)    :: a -> d
  , update :: a -> d -> Action ()
  }

toRegFile :: RTL.RegFileRTL a d -> RegFile a d
toRegFile rf = RegFile (RTL.lookupRTL rf) (\a d -> A (RTL.updateRTL rf a d))

-- |Create register file with initial contents
makeRegFileInit :: forall a d. (Bits a, Bits d) =>
                     String -> Module (RegFile a d)
makeRegFileInit initFile = M (liftM toRegFile $ RTL.makeRegFileInit initFile)

-- |Create uninitialised register file
makeRegFile :: forall a d. (Bits a, Bits d) => Module (RegFile a d)
makeRegFile = M (liftM toRegFile RTL.makeRegFile)

-- |Terminate simulator
finish :: Action ()
finish = A RTL.finish

-- |Display statement
instance RTL.Displayable (Action a) where
  disp x = A (RTL.disp x)

-- |Convert module to a netlist
netlist :: Module () -> IO [Net]
netlist m = RTL.netlist (runModule m)