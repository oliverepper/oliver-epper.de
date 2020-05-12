---
date: 2020-02-21 9:41
description: A deprecated way to save Codables
tags: Swift, iOS, Codables
---
# A deprecated way to save Codables — but why?

I was looking for a way to save a lot of Codables that emerge over a potentially long timespan. Just keeping them in memory looked like the obvious thing to do but I wanted something failsafe and persistent.

Saving a Codable to a file in Swift couldn’t be easier: `JSONEncoder.encode(T)` returns `Data`. That can be written to an `URL` via `write(to: URL)`.

But what if I want to append?

I for sure don’t want to load the data from a file, decode it into a JSON array, append the new Codable to the array, encode the array to data and then use that data to overwrite the file.

I do the following:

An instance of `CodableFileBuffer<T>` keeps an open FileHandle on an URL and whenever I call `append(codable)` on that buffer it encodes to data and writes that data to the file handle.

```Swift
public func append(_ codable: T) {
    // encode codable
    guard let data = try? encoder.encode(codable) else {
        fatalError("Cannot encode \(codable)")
    }

    // write to FileHandle
    fileHandle.write(data)
    fileHandle.write(",".data(using: .utf8)!)

    // log
    os_log("Did append codable to CodableFileBuffer at: %@", log: OSLog.CodableFileBuffer, type: .debug, fileURL.lastPathComponent)
}
```

This could use a little more error handling but it is just for demo purpose. Bare with me.

The only thing not completely obvious happens on line 9. This ist just the comma that is required to form a JSON array. When I create the FileHandle I immediately write an opening square bracket to the file and the `retrieve() -> [Codable]` function appends the closing square-bracket to the data before it passes it to the JSONDecoder.

So the files content loos like this:

```txt
// after initializing
[

// after writing the first codable
[{"id":1, "key": "value_one"},

// after writing the second codable
[{"id":1, "key": "value_one"},{"id":2, "key": "another_value"},

// the data that gets passed to the JSONDecoder looks like this
[{"id":1, "key": "value_one"},{"id":2, "key": "another_value"},]
```

I know the trailing comma is ugly and no valid json. It would be an easy fix but actually the `JSONDecoder` is pretty forgiving, here.

So what do we have now?

We have a Buffer that can be used like this:

```Swift
struct MyCodable: Codable {
    var id: Int
    var key: String
}

let buffer = CodableFileBuffer<MyCodable>()

buffer.append(MyCodable(id: 1, key: "value_one"))
buffer.append(MyCodable(id: 2, key: "another_value"))

let myCodables = buffer.retrieve()
```

Neat, isn’t it?

I use it to append thousands of Codables and it works pretty nice, so far. I measured it with instruments using tens of thousands to Codables. And I use it on real devices running for days.

Here’s the complete thing:

[CodeableFileBuffer](https://github.com/oliverepper/CodableFileBuffer)

So what’s next?

I have a few questions I’d like to discuss:

1. Why is `FileHandle.write` deprecated? It sure doesn’t look swifty. It can throw exceptions without beeing marked as throwing.
2. How are we supposed to replace this? How does the `writeabilityHandler` work? Can anyone provide an example?
3. What do you think? I guess there must be other or better ways to buffer Codables on disk.

I’d really appreciate your ideas.
