---
date: 2024-08-18 9:42
title: Learning Haskell – Functors
description: Build your own functor typeclass and a few conforming types
tags: Haskell, Functor
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

_Disclaimer: This content comes straight out of the fantastic book [Effective Haskell](https://effective-haskell.com) written by [Rebecca Skinner](https://rebeccaskinner.net). I was only talking notes and doing my own little experiments. Original Haskell content by me will follow shortly._

I am learning Haskell and I am having great fun with it. My goal is to be able to apply [Denotational Design](https://www.typetheoryforall.com/episodes/denotational-design) as described by [Conal Elliott](http://conal.net) to the software I build and learning Haskell gives me a better understanding of the fundamentals, through practice.

I believe that the programming language you work in influences the way you thing and so I make a real effort to be fluent in multiple languages with different paradigms.

# Functor
For the mathematical definition of functor see [Wikipedia](https://en.wikipedia.org/wiki/Functor#Definition).

In programming a functor is a thing that knows how to apply a function to a certain structure preserving that structure. The functor does this via the `fmap` function that the typeclass `Functor` describes:

`fmap :: (a -> b) -> f a -> f b`

Read this as: With a function from a to b and a functor of a it returns a functor of b.

There is another function `<$` in the functor typeclass that is called replace:

`(<$) :: a -> f b -> f a`

Imagine the function you want to apply to the functor always returns the same value then the signature becomes clear: With a constant value a and a functor of b it returns a functor of a.

This can always be expressed with `fmap` giving it `const` as it's function.

Let build our own Functor typeclass in Haskell:

```haskell
class MyFunctor f where
  myFMap :: (a -> b) -> f a -> f b
  myReplace :: a -> f b -> f a
  myReplace a f = myFMap (const a) f
```

As mentioned myReplace is already implemented for every instance of out MyFunctor class.

## List
To see this in action let's build something simple as our structure like a list:

```haskell
data MyList a = Empty | MyList a (MyList a) deriving Show
```

This is your standard recursive list data structure. Let's make it an instance of MyFunctor:

```haskell
instance MyFunctor MyList where
  myFMap _ Empty = Empty
  myFMap f (MyList a rest) = MyList (f a) (myFMap f rest)
```

There you have it. Now let's invent infix operators for `myFMap` and `myReplace` and try them out:

```haskell
infixl 4 <.>
(<.>) = myFMap

infixl 4 <.
(<.) = myReplace

(+1) <.> MyList 1 Empty         -- Mylist 2 Empty
99 <. Empty                     -- Empty
99 <. MyList 1 (MyList 2 Empty) -- MyList 99 (MyList 99 Empty)
```

So you see the Functor instance of our MyList can apply a function to every element preserving the structure of the MyList. The function can change the type of the element but it will always be a list with the same number of elements:

```haskell
show <.> MyList 1 Empty         -- MyList "1" Empty
```

## Maybe
Let's build another structure that can implement the Functor typeclass. I will use German words for the type name and the constructors because just like `List Maybe` already is an instance of `Functor` and although we will implement `MyFunctor` I think it makes it clearer:

```
data Vielleicht a = Nix | Ein a deriving Show

instance MyFunctor Vielleicht where
  myFMap _ Nix = Nix
  myFMap f (Ein a) = Ein (f a)
```

Since `MyList` and `Vielleicht` are of the same kind: `* -> *` that means both taking one parameter to construct a type this was pretty mechanic. Nothing new, here.

## Either
I am using German words again to build an `Either` type that has the kind: `* -> * -> *`. This means the type constructor will need two parameters to construct a type.

```
data Entweder a b = Links a | Rechts b deriving show
```

We can use that to build a save division function:

```haskell
teile :: (Eq a, Fractional a) => a -> a -> Entweder String a
teile a b
  | b == 0      = Links "NaN"
  | otherwise   = Rechts $ a / b
```

Now let's think about the Functor instance for `Entweder`. I might want to pass `round` to the result of `teile` but that only needs to be done if the result is an instance of `Rechts`. I don't want to `round` the String.

So we can implement a sane Functor instance like this:

```haskell
instance MyFunctor (Entweder a) where
  myFMap _ (Links a)    = (Links a)
  myFMap f (Rechts b)   = Rechts $ f a
```

Let's try it out:

```
round <.> teile 5 2     -- Rechts 2
```

# Functions
Rebecca shows something else that is cool. Let's create a wrapper for a function so that we can show that even a function can be a functor:

```haskell
newtype Funktion a b = Funktion
  { run :: (a -> b) }

instance MyFunctor (Funktion a) where
  myFMap f (Funktion g) = Funktion (f . g)

run (show <.> Funktion (+1)) 12 -- "13" the type is String, now
```

Type `:i Functor` in ghci and you can see that `(->) r` is indeed a `Functor` instance. In hindsight this seems obvious. The functor knows how to apply a function f to the result of the function g and gives you a new function f after g – thus the structure is maintained.