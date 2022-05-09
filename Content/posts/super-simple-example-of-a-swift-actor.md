---
date: 2022-01-31 9:41
title: Super Simple Example of a Swift Actor
description: Use an actor to prevent a data race
tags: Swift, async, actor
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

Besides classes, structs and enum Swift has actors, now. Let's create a super simple example of what an actor can do.

## Let's build something super simple

```Swift
class Counter {
    var value = 0

    func increment() {
        value += 1
    }

    func decrement() {
        value -= 1
    }
}
```

Let's build a view model that uses a counter:

```Swift
final class Model: ObservableObject {
    @Published var counterValue: String?
    private var counter: Counter

    init() {
        counter = Counter()
        update()
    }

    func increment(times: Int) {
        for _ in 1...times {
            counter.increment()
        }
        update()
    }

    func decrement(times: Int) {
        for _ in 1...times {
            counter.decrement()
        }
        update()
    }

    private func update() {
        assert(Thread.isMainThread)
        counterValue = counter.value.description
    }
}
```

and a view that uses the view model:

```Swift
struct ContentView: View {
    @StateObject var model = Model()

    var body: some View {
        VStack {
            if let value = model.counterValue {
                Text(value)
            }
            Button("do something...") {
                let start = Date()
                model.increment(times: 1_000_000)
                model.increment(times: 1_000_005)
                model.decrement(times: 2_000_000)
                let elapsed = Date().timeIntervalSince(start)
                print(String(format: "%.05f", elapsed))
            }
        }
        .padding()
    }
}
```

Press the button and the desired output `5` will appear. The time spend in the buttons closure will be printed to the console.

## Now break it

Let's break it by offloading the millions of incrementens and decrements to another Thread. Change the view model like this:

```Swift
func increment(times: Int) {
    DispatchQueue(label: .init()).async {
        for _ in 1...times {
            self.counter.increment()
        }
        DispatchQueue.main.async {
            self.update()
        }
    }
}
```

or

```Swift
func decrement(times: Int) {
    Thread {
        for _ in 1...times {
            self.counter.decrement()
        }
        DispatchQueue.main.async {
            self.update()
        }
    }.start()
}
```

If you run this now, the time spend in the "do something..." button closure is close to 0, but the UI no longer shows `5`. There's your obvious data-race.

## Fix it

Let's go into the `Counter` and introduce a queue that will perform all mutations to the value property:

```Swift
class Counter {
    var value = 0

    private var queue = DispatchQueue(label: "Counter")

    func increment() {
        queue.sync {
            value += 1
        }
    }

    func decrement() {
        queue.sync {
            value -= 1
        }
    }
}
```

The closure returns immediately and after some time (you really have to give it some time) we're getting the desired `5` in the UI again. There's a high chance that there are different values shown before all the operations are performed.
Press again and it will settle with 10. All good, again.

## Fix it with an actor

Now let's use an actor. Go back to the original `Counter` but make it an actor.

```Swift
actor Counter {
    var value = 0

    func increment() {
        value += 1
    }

    func decrement() {
        value -= 1
    }
}
```

The cool thing is that you can have the compiler guide you from now on. To improve even further on that mark the `counterValue` property in the view model as `@MainActor`.

```Swift
@MainActor @Published var counterValue: String?
```

Now build and lets go through the errors.

The first error message is:

> `Actor-isolated instance method 'increment()' can not be referenced from a non-isolated context`

so let's fix that by awaiting the call to `counter.incerement()` from an async context. Change `increment(times:)` to this:

```Swift
func increment(times: Int) {
    Task {
        for _ in 1...times {
            await counter.increment()
        }
        update() // not done, yet
    }
}
```

Note that you can drop `self` from `self.counter.increment()`, again. Do the same for `decrement(times:)` and you'll get to the next error:

> `Property 'counterValue' isolated to global actor 'MainActor' can not be mutated from this context`

Xcode even gives us a code action, now. Press fix for `'Add '@MainActor' to make instance method 'update()' part of global actor 'MainActor'`. Once `update()` is isolated on the MainActor you need to await all calls to it. The reason is that Swift might need to perform a context switch because your code might not be running on the `MainActor` at the time you call `update()`.

Since `init()` is a normal Swift function and not an async function we need to put the call to `update()` in a Task block:

```Swift
init() {
    counter = Counter()
    Task {
        await update()
    }
}
```

If I understand everything right an async function has it's own execution stack which can be executed and suspended from an operating system thread. So the last error message:

> `Actor-isolated property 'value' can not be referenced from the main actor`

tells us that the code:

```Swift
@MainActor private func update() {
    assert(Thread.isMainThread)
    counterValue = counter.value.description
}
```

has an async execution context (the MainActor) and wants to read a value from another Actor (our Counter Actor). So for this to work we need to send the Counter Actor the message that we want to read its `value` property. This needs to be awaited. So fix the code like this:

```Swift
@MainActor private func update() async {
    assert(Thread.isMainThread)
    counterValue = await counter.value.description
}
```

Here's the updated view model:

```Swift
final class Model: ObservableObject {
    @MainActor @Published var counterValue: String?
    private var counter: Counter

    init() {
        counter = Counter()
        Task {
            await update()
        }
    }

    func increment(times: Int) {
        Task {
            for _ in 1...times {
                await counter.increment()
            }
            await update()
        }
    }

    func decrement(times: Int) {
        Task {
            for _ in 1...times {
                await counter.decrement()
            }
            await update()
        }
    }

    @MainActor private func update() async {
        assert(Thread.isMainThread)
        counterValue = await counter.value.description
    }
}
```

The `@MainActor` annotation of the `@Published` property `counterValue` helps with error messages. Get in the habit and think: "I will use this property in the view so it needs to be modified on the main actor."