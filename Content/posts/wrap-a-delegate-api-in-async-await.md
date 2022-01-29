---
date: 2022-01-28 9:41
title: Wrap a delegate API in async/await
description: How to use an existing delegate API with the new Swift concurrency system
tags: Swift, async, delegate
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

The new Swift concurrency system looks super promising in terms of cleaner and easier to reason about code in a complex application. As with SwiftUI and AppKit/UIKit there's an opportunity to wrap existing APIs and make them availabe via the new APIs.

## Create a delegate based sample API
Although `URLSession` already has an async/await API we use it to build a super simple delegate based API.

```Swift
protocol DownloaderDelegate: AnyObject {
    func downloader(_ downloader: Downloader, didFinishDownloadingData data: Data)
    func downloader(_ downloader: Downloader, didFailWithError error: Error)
    func downloader(_ downloader: Downloader, didFailWithHttpStatusCode code: Int)
}
```

```Swift
struct Downloader {
    weak var delegate: DownloaderDelegate?

    func download(url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                delegate?.downloader(self, didFailWithError: error)
                return
            }

            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                fatalError()
            }

            guard statusCode == 200 else {
                delegate?.downloader(self, didFailWithHttpStatusCode: statusCode)
                return
            }

            guard let data = data else {
                fatalError()
            }

            delegate?.downloader(self, didFinishDownloadingData: data)
        }.resume()
    }
}
```

This API is pretty simple you call `Downloader().download(url:)` and you get either your data, or an error via the delegate protocol.

## Async/Await
What we would like to achieve is the following: `DownloaderWrapper().download(url:)` which would be an async throwing function that returns either `Data` or throws an `error`. So lets sketch that out:

```Swift
func download(url: URL) async throws -> Data {
    return ...
}
```

From the delegate functions we need to comminucate back to the thing that we want to return. Roughly like with Futures and Promises.
In the new Swift concurrency system that thing is a `Continuation`.

```Swift
func download(url: URL) async throws -> Data {
    return try await withCheckedThrowingContinuation {
        download = $0 // save the continuation to be fullfilled by the delegate functions
        downloader.download(url: url) // initialize the download via the original API
    }
}
```

So the complete Wrapper looks like this:

```Swift
final class DownloaderWrapper: DownloaderDelegate {
    enum HTTPError: Error {
        case code(Int)
    }

    typealias DownloadContinuation = CheckedContinuation<Data, Error>
    private var download: DownloadContinuation?
    private var downloader: Downloader

    init() {
        downloader = Downloader()
        downloader.delegate = self
    }

    func downloader(_ downloader: Downloader, didFinishDownloadingData data: Data) {
        download?.resume(with: .success(data))
    }

    func downloader(_ downloader: Downloader, didFailWithError error: Error) {
        download?.resume(with: .failure(error))
    }

    func downloader(_ downloader: Downloader, didFailWithHttpStatusCode code: Int) {
        download?.resume(with: .failure(HTTPError.code(code)))
    }

    func download(url: URL) async throws -> Data {
        return try await withCheckedThrowingContinuation {
            download = $0
            downloader.download(url: url)
        }
    }
}
```

## Using the new API
So inside a view you can now use the new API in an asynchronous context via a Task

```Swift
Button("Download") {
    Task {
        do {
            let data = try await DownloaderWrapper().download(url: URL(string: "https://oliver-epper.de")!)
            text = String(data: data, encoding: .utf8)
        } catch {
            if case let DownloaderWrapper.HTTPError.code(code) = error {
                errorMessage = "HTTP Error: \(code)"
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

Very cool! Thanks [Matz](https://twitter.com/ludwigmatthias) and Andy Inbanez [async/await in Swift](https://www.andyibanez.com/posts/converting-closure-based-code-into-async-await-in-swift/)