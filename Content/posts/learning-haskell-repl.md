---
date: 2024-08-18 9:43
title: Learning Haskell – REPL
description: I build a REPL in Haskell
tags: Haskell, Functor
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

Because I am doing a lot of library work and I prefer text-based interfaces I always enjoy having a REPL (Read Evaluate Print Loop) next to my libraries for easy testing.

Here's my first Haskell REPL. This is actually quite nice, I think.

```haskell
module Cli where

import System.IO
    ( hSetBuffering
    , hSetEcho
    , hGetChar
    , hGetLine
    , hFlush
    , stdin
    , stdout
    , BufferMode(NoBuffering,LineBuffering)
    )

import Control.Exception
    ( Exception
    , throwIO
    , try
    )

import System.Console.ANSI
    ( getCursorPosition
    , setCursorPosition
    , clearScreen
    )

data Command = One | Two String | Clear | Cancel deriving (Eq, Show)

data UnknownCommandException = UnknownCommand Char deriving Show
instance Exception UnknownCommandException

moveLeft :: IO ()
moveLeft = do
    position <- getCursorPosition
    case position of
        Just (x, y) -> 
            if y > 0
                then setCursorPosition x (y - 1)
                else return()
        _ -> return ()

getCommand :: String -> IO Command
getCommand prompt = do
    hSetBuffering stdin NoBuffering
    hSetEcho stdin False
    putStr $ prompt <> ": "
    hFlush stdout
    input <- hGetChar stdin
    case input of
        'o'                         -> return One
        't'                         -> readTwo
        '0'                         -> return Clear
        c | c == 'c' || c == 'q'    -> return Cancel
        _                           -> throwIO (UnknownCommand input)

readTwo :: IO Command
readTwo = do
    moveLeft
    putStr "Enter text to reverse: "
    hFlush stdout
    hSetBuffering stdin LineBuffering
    hSetEcho stdin True
    input <- hGetLine stdin
    return $ Two input

handleCommand :: Command -> IO Bool
handleCommand Cancel = putChar '\n' >> return False
handleCommand (Two str) = do
    putStrLn $ reverse str
    return True
handleCommand Clear = do
    clearScreen
    setCursorPosition 0 0
    return True
handleCommand cmd = do
    putStrLn $ show cmd
    return True

handleUnknownCommandException :: IO Bool -> IO Bool
handleUnknownCommandException ioAction = do
    result <- try $ ioAction :: IO (Either UnknownCommandException Bool)
    case result of
        Left err ->
            print (err :: UnknownCommandException)
            >> return True
        Right continue ->
            return continue

loop' :: IO Bool -> IO ()
loop' ioAction =
    ioAction >>= \continue ->
        if continue then loop' ioAction
        else return ()

repl :: IO ()
repl = loop' $ handleUnknownCommandException $ getCommand "$" >>= handleCommand
```

This is not necessarily the way you would want to do it. I wanted getCommand to throw an exception and I wanted a clear separation between the elements that form the REPL. I have just started learning Haskell so suggestions are very welcome.