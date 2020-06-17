---
date: 2020-06-17 9:41
title: Automatically stamp an object with a unique pin
description: Stamp an object with an unique pin before saving into the database
tags: Swift, Server, Vapor, Fluent
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

I recently started using Vapor and I love it! Using Swift on the server is sweet and Vapor has a really nice API. I wanted to do a "simple" thing that turned out to be harder than I initially thought it would be but Swift and Vapor made it actually fun to strive for a nice solution.

## What I wanted to do

Imagine that you want to store something away but first put a little sticker on it. You have a box full of things to store, a sheet of stickers and the cabinet where you want to put the things. So:

```Pseu
take_a_thing
take_a_sticker
put_sticker_on_thing
put_thing_in_cabinet
```

Easy, isn't it?

The `take_a_sticker` part can be tricky. What if you have someone that helps you and you both grab the same sticker? Clearly you want to SELECT and DELETE the sticker (from a database) in an atomic operation.

## How to implement the ModelMiddleware?

With Vapor you can register a `ModelMiddleware` that you can use to provide lifecycle functions for your model. Let's say you want to hook into the create process:

```Swift
struct ThingMiddleware: ModelMiddleware {
    func create(model: Thing, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        print("This will happen before the create")
        next.create(model, on: db).map {
            print("This will happen after the create")
        }
    }
}
```

Isn't it cool how Swift infers the type for the ThingMiddleware through the create functions model parameter? It doesn't require you to write:

```Swift
struct ThingMiddleware: ModelMiddleware {
    typealias model = Thing

    func create(model: Model, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        // ...
    }
}
```

So we're handling with Futures here.

Let's try to express the pseudocode from above. What about this:

```swift
// ATTENTION: THIS DOES NOT WORK!
struct PinErrror: Error { }

struct ClientConfigMiddleware: ModelMiddleware {
    func create(model: ClientConfig, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        return self.getPin(from: db).flatMap { pin in
            model.pin = pin
            return next.create(model, on: db)
        }
    }

    private func getPin(from db: Database) -> EventLoopFuture<Int> {
        guard let sql = db as? SQLDatabase else {
            fatalError()
        }
        return sql.raw("SELECT * FROM pins LIMIT 1").first().flatMapThrowing { row in
            if let pin = try? row?.decode(column: "pin", as: Int.self) {
                _ = sql.raw("DELETE FROM pins WHERE pin='\(String(pin))'").run()
                return pin
            } else {
                throw PinErrror()
            }
        }
    }
}
```


The logic basically says:


```pseudocode
create:
	return getNextSticker.if_ok
		put_sticker_on_model
		save_model

getNextSticker:
	return get sicker_from_db.if_ok
		delete_sticker_from_db.if_ok
			return sticker
```

That should do it, right?

Well not quite. With a blocking database driver I guess that would work but what happens in Vapor is that if you create a bunch of model objects they all get the same sticker!

We need something a bit more clever. After doing a bit of research and asking around the people in the Vapor Discord Tanner the inventor of Vapor pointed me to a post on Stackoverflow that had a great idea for situation that was quite similar:

## Why not call dibs on the row, first?

What if the code wouldn't just select (and then delete) the first entry, but mark it with something if it is not marked, yet. For example the current thread-id, a timestamp, or a uuid? Then the code can select that very entry while everyone else can continue with their own marked entries.

So here's how you can make it work in code:

```Swift
struct PinError: Error { }

struct ClientConfigMiddleware: ModelMiddleware {
    func create(model: ClientConfig, on db: Database, next: AnyModelResponder) -> EventLoopFuture<Void> {
        return self.getNextPin(from: db).flatMap { pin in
            model.pin = pin
            return next.create(model, on: db)
        }
    }

    private func getNextPin(from db: Database) -> EventLoopFuture<Int> {
        guard let sql = db as? SQLDatabase else {
            fatalError()
        }
        let selector = UUID()
        return sql.raw("UPDATE pins SET selector='\(selector.uuidString)' WHERE pin = (SELECT pin FROM pins WHERE selector IS NULL LIMIT 1)").run().flatMap {
            return sql.raw("SELECT pin FROM pins WHERE selector='\(selector.uuidString)'").first().flatMapThrowing { row in
                if let pin = try? row?.decode(column: "pin", as: Int.self) {
                    return pin
                }
                throw PinError()
            }
        }
    }
}
```

So now we have:

```pseudocode
create:
	return getNextSticker.if_ok
		put_sticker_on_model
		save_model

getNextSticker:
	return get mark_a_sticker_that_is_not_yet_marked_with_myId.if_ok
		return select_the_sticker_that_is_marked_with_myId.if_ok
			return sticker
```

The pins table is a prepopulated table that has two columns. One for the actual pin and one called selector that is prepoulated with NULL. The `getNextPin` function writes a uuid that it saves in the selector column and can then read a pin by selecting the row with the matching selector. Pretty neat, isn't it?