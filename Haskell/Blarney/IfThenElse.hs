{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}

{-|
Module      : Blarney.IfThenElse
Description : Overloaded if/then/else
Copyright   : (c) Matthew Naylor, 2019
License     : GPL-3
Maintainer  : mattfn@gmail.com
-}
module Blarney.IfThenElse where

import Prelude

-- Overloaded if/then/else
class IfThenElse b a where
  ifThenElse :: b -> a -> a -> a

instance IfThenElse Bool a where
  ifThenElse False a b = b
  ifThenElse True a b = a
