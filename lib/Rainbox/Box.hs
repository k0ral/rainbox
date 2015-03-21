{-# LANGUAGE OverloadedStrings #-}
-- | Working with 'Box'.
--
-- A 'Box' is a rectangular block of text.  You can paste 'Box'
-- together to create new rectangles, and you can grow or reduce
-- existing 'Box' to create new 'Box'es.
--
-- There are only six primitive functions that make a 'Box':
--
-- * 'B.blank' - formats a blank box with nothing but a (possibly)
-- colorful background.  Useful to paste to other 'Box' to provide
-- white space.
--
-- * 'B.chunks' - Makes a box out of Rainbow 'Chunk'.
--
-- * 'B.catH' - paste 'Box' together horizontally
--
-- * 'B.catV' - paste 'Box' together vertically
--
-- * 'B.viewH' - view a 'Box', keeping the same height but possibly
-- trimming the width
--
-- * 'B.viewV' - view a 'Box', keeping the same width but possibly
-- trimming the height
--
-- The other functions use these building blocks to do other useful
-- things.
--
-- There are many crude diagrams in the Haddock documentation.  A
-- dash means a character with data; a period means a blank
-- character.  When you print your 'Box', the blank characters will
-- have the appropriate background color.
module Rainbox.Box
  (
  -- * Height and columns
    Height(..)
  , B.height
  , Width(..)
  , B.HasWidth(..)

  -- * Alignment
  , Align
  , Vert
  , Horiz
  , B.center
  , B.top
  , B.bottom
  , B.left
  , B.right

  -- * Box properties
  , B.Bar(..)
  , B.barToBox
  , B.barsToBox
  , B.Box
  , B.unBox

  -- * Making Boxes
  , B.blank
  , blankH
  , blankV
  , B.chunks
  , chunk

  -- * Pasting Boxes together
  , B.catH
  , B.catV
  , sepH
  , sepV
  , punctuateH
  , punctuateV

  -- * Viewing Boxes
  , view
  , B.viewH
  , B.viewV

  -- * Growing Boxes
  , grow
  , growH
  , growV
  , column

  -- * Resizing
  , resize
  , resizeH
  , resizeV

  -- * Printing Boxes
  , render
  , printBox
  ) where

import Data.Monoid
import Data.List (intersperse)
import qualified Data.Text as X
import Rainbow
import qualified Rainbox.Box.Primitives as B
import Rainbox.Box.Primitives
  ( Box
  , Align
  , Horiz
  , Vert
  , Height(..)
  , Width(..)
  , unBox
  )
import qualified Data.ByteString as BS

--
-- # Box making
--

-- | A blank horizontal box with a given width and no height.
blankH
  :: Radiant
  -- ^ Background colors
  -> Int
  -- ^ Box width
  -> Box
blankH bk i = B.blank bk (Height 0) (Width i)

-- | A blank vertical box with a given length.
blankV
  :: Radiant
  -- ^ Background colors
  -> Int
  -- ^ Box height
  -> Box
blankV bk i = B.blank bk (Height i) (Width 0)

-- | A Box made of a single 'Chunk'.
chunk :: Chunk -> Box
chunk = B.chunks . (:[])

-- | Grow a box.  Each dimension of the result 'Box' is never smaller
-- than the corresponding dimension of the input 'Box'.  Analogous to
-- 'view', so you give the resulting dimensions that you want.  The
-- alignment is analogous to 'view'; for instance, if you specify
-- that the alignment is 'top' and 'left', the extra padding is
-- added to the right and bottom sides of the resulting 'Box'.

grow
  :: Radiant
  -- ^ Background colors
  -> Height
  -> Width
  -> Align Vert
  -> Align Horiz
  -> Box
  -> Box
grow bk (B.Height h) (B.Width w) av ah
  = growH bk w ah
  . growV bk h av

-- | Grow a 'Box' horizontally.

growH
  :: Radiant
  -- ^ Background colors
  -> Int
  -- ^ Resulting width
  -> Align Horiz
  -> Box
  -> Box
growH bk tgtW a b
  | tgtW < w = b
  | otherwise = B.catH bk B.top [lft, b, rt]
  where
    w = B.width b
    diff = tgtW - w
    (lft, rt) = (blankH bk wl, blankH bk wr)
    (wl, wr)
      | a == B.center = B.split diff
      | a == B.left = (0, diff)
      | otherwise = (diff, 0)

-- | Grow a 'Box' vertically.
growV
  :: Radiant
  -- ^ Background colors
  -> Int
  -- ^ Resulting height
  -> Align Vert
  -> Box
  -> Box
growV bk tgtH a b
  | tgtH < h = b
  | otherwise = B.catV bk B.left [tp, b, bt]
  where
    h = B.height b
    diff = tgtH - h
    (tp, bt) = (blankV bk ht, blankV bk hb)
    (ht, hb)
      | a == B.center = B.split diff
      | a == B.top = (0, diff)
      | otherwise = (diff, 0)

-- | Returns a list of 'Box', each being exactly as wide as the
-- widest 'Box' in the input list.
column
  :: Radiant
  -- ^ Background colors
  -> Align Horiz
  -> [Box]
  -> [Box]
column bk ah bs = map (growH bk w ah) bs
  where
    w = maximum . (0:) . map B.width $ bs

view
  :: Height
  -> Width
  -> Align Vert
  -> Align Horiz
  -> Box
  -> Box
view h w av ah
  = B.viewH (B.unWidth w) ah
  . B.viewV (B.unHeight h) av

--
-- # Resizing
--

-- | Resize a 'Box'.  Will grow or trim it as necessary in order to
-- reach the resulting size.  Returns an empty 'Box' if either
-- 'Height' or 'Width' is less than 1.

resize
  :: Radiant
  -- ^ Background colors
  -> Height
  -> Width
  -> Align Vert
  -> Align Horiz
  -> Box
  -> Box
resize bk h w av ah
  = resizeH bk (unWidth w) ah
  . resizeV bk (unHeight h) av

-- | Resize horizontally.
resizeH
  :: Radiant
  -- ^ Background colors
  -> Int
  -- ^ Resulting width
  -> Align Horiz
  -> Box
  -> Box
resizeH bk w a b
  | bw < w = growH bk w a b
  | bw > w = B.viewH w a b
  | otherwise = b
  where
    bw = B.width b

-- | Resize vertically.
resizeV
  :: Radiant
  -- ^ Background colors
  -> Int
  -- ^ Resulting height
  -> Align Vert
  -> Box
  -> Box
resizeV bk h a b
  | bh < h = growV bk h a b
  | bh > h = B.viewV h a b
  | otherwise = b
  where
    bh = B.height b

--
-- # Glueing
--

-- | @sepH sep a bs@ lays out @bs@ horizontally with alignment @a@,
--   with @sep@ amount of space in between each.
sepH
  :: Radiant
  -- ^ Background colors
  -> Int
  -- ^ Number of separating spaces
  -> Align Vert
  -> [Box]
  -> Box
sepH bk sep a = punctuateH bk a bl
  where
    bl = blankH bk sep

-- | @sepV sep a bs@ lays out @bs@ vertically with alignment @a@,
--   with @sep@ amount of space in between each.
sepV
  :: Radiant
  -- ^ Background colors
  -> Int
  -- ^ Number of separating spaces
  -> Align Horiz
  -> [Box]
  -> Box
sepV bk sep a = punctuateV bk a bl
  where
    bl = blankV bk sep

-- | @punctuateH a p bs@ horizontally lays out the boxes @bs@ with a
--   copy of @p@ interspersed between each.
punctuateH
  :: Radiant
  -- ^ Background colors
  -> Align Vert
  -> Box
  -> [Box]
  -> Box
punctuateH bk a sep = B.catH bk a . intersperse sep

-- | A vertical version of 'punctuateH'.
punctuateV
  :: Radiant
  -- ^ Background colors
  -> Align Horiz
  -> Box
  -> [Box]
  -> Box
punctuateV bk a sep = B.catV bk a . intersperse sep

-- | Convert a 'Box' to Rainbow 'Chunk's.  You can then print it, as
-- described in "Rainbow".
render :: Box -> [Chunk]
render bx = case unBox bx of
  B.NoHeight _ -> []
  B.WithHeight rw ->
    concat . concat . map (: [["\n"]])
    . map renderRod $ rw

renderRod :: B.Rod -> [Chunk]
renderRod = map toChunk . B.unRod
  where
    toChunk = either spcToChunk id . B.unNibble
    spcToChunk ss =
      chunkFromText (X.replicate (B.numSpaces ss) (X.singleton ' '))
      <> back (B.spcBackground ss)

-- | Prints a Box to standard output.  The highest number of available
-- colors are used, using 'byteStringMakerFromEnvironment' from
-- "Rainbow".
printBox :: Box -> IO ()
printBox b = do
  mkr <- byteStringMakerFromEnvironment
  mapM_ BS.putStr . chunksToByteStrings mkr . render $ b
