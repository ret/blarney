-- Single-element FIFO

module FIFO where

import Blarney

-- FIFO interface
data FIFO a =
  FIFO {
    notFull  :: Bit 1
  , notEmpty :: Bit 1
  , enq      :: a -> RTL ()
  , deq      :: RTL ()
  , first    :: a
  }

-- FIFO module (simple one-element FIFO)
makeFIFO :: Bits a => RTL (FIFO a)
makeFIFO = do
  -- Register holding the one element
  reg :: Reg a <- makeReg (unpack 0)

  -- Register defining whether or not FIFO is full
  full :: Reg (Bit 1) <- makeReg 0

  -- Methods
  let notFull = val full .==. 0

  let notEmpty = val full .==. 1

  let enq a = do
        reg <== a
        full <== 1

  let deq = full <== 0

  let first = val reg

  -- Return interface
  return (FIFO notFull notEmpty enq deq first)

-- Top-level module
top :: RTL ()
top = do
  -- Counter
  timer :: Reg (Bit 8) <- makeReg 0
  timer <== val timer + 1

  -- Instantiate a FIFO
  fifo :: FIFO (Bit 8) <- makeFIFO

  -- Writer side
  when (notFull fifo) $ do
    enq fifo (val timer)
    display "Enqueued " (val timer)

  -- Reader side
  when (notEmpty fifo) $ do
    deq fifo
    display "Dequeued " (first fifo)

  -- Terminate after 100 cycles
  when (val timer .==. 100) finish

-- Main function
main :: IO ()
main = netlist top >>= writeVerilog "/tmp/fifo.v"
