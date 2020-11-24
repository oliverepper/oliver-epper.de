---
date: 2020-11-24 9:41
title: How to wrap a C library in a swift package
description: How to wrap a c-library in a swift package
tags: SwiftPM
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---
There are a few great C/C++ libraries out there that you might want to use in your Swift application. Most of the time you'll find a wrapper already, but not all of the times. Or maybe you want something that is carefully tailored to your project needs.

Chris Eidhof from [objc.io](https://www.objc.io) has a wrapper around the cmark library: [CommonMark-Swift](https://github.com/chriseidhof/commonmark-swift). Let's take that as an example and see how this can be achieved.

## Create the library package

```bash
mkdir ~/CommonMark
cd ~/CommonMark
swift package init --type library
```

Before we can actually use the cmark library it needs to be installed. I use brew:

```bash
brew install cmark
```

Now let's edit the Package.swift

```Swift
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "CommonMark",
    platforms: [
        .macOS("11")
    ],
    products: [
        .library(name: "CommonMark", targets: ["CommonMark"]),
        .library(name: "Ccmark", targets: ["Ccmark"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "CommonMark", dependencies: [
            "Ccmark"
        ]),
        .systemLibrary(
            name: "Ccmark",
            pkgConfig: "libcmark",
            providers: [
                .brew(["commonmark"])
            ]),
        .testTarget(
            name: "CommonMarkTests",
            dependencies: ["CommonMark"]),
    ]
)
```

So we're building two products:

- CommonMark
- Ccmark

In the target section you can see that Ccmark is the name that we'll use for libcmark. The leading uppercase C seems to be a standard.

For this to work we need to create a directory `Ccmark` below our `Sources` directory and create the file: `module.modulemap` with the following content:

```
module Ccmark [system] {
    header "/usr/local/include/cmark.h"
    link "libcmark"
    export *
}
```

This tells the system where to find the header for libcmark and the library itself. The `[system]` attribute tells the compiler that `cmark.h` is a system header and more warnings will be ignored.

Voila! That's it. We can now use the cmark library in our Swift code.

## Create a Swift API

Chris created another target: `CommonMark` that gives the user a nicer API to work with. Let's build a minimal version of that.

Edit `Sources/CommonMark/CommonMark.swift` like this:

```Swift
import Foundation
import Ccmark // this wraps libcmark

public class Node {
    let node: OpaquePointer

    public init(_ node: OpaquePointer) {
        self.node = node
    }
    
    public init?(markdown: String) {
        guard let node = cmark_parse_document(markdown, markdown.utf8.count, CMARK_OPT_DEFAULT) else {
            return nil
        }
        self.node = node
    }

    deinit {
        guard type == CMARK_NODE_DOCUMENT else { return }
        cmark_node_free(node)
    }

    public var type: cmark_node_type {
        return cmark_node_get_type(node)
    }

    public var typeString: String {
        return String(cString: cmark_node_get_type_string(node))
    }

    public var children: [Node] {
        var result: [Node] = []
        
      	// cmark_node_first_child can return nil
        var child = cmark_node_first_child(node)
        while let unwrapped = child {
            result.append(Node(unwrapped))
            child = cmark_node_next(child)
        }
        return result
    }
}
```

This is pretty straight forward. The class Node encapsulates a pointer to the cmark node type. It gets initialized in the failable initializer through the call to the function `cmark_parse_document`. For this to work you need to import Ccmark.

> If you want to read the documentation for libcmark you can open the man-page with `man 3 cmark`. The `3` opens the library documentation as opposed to the implicit `1` which would open the cmark commands man page.

This will not compile yet, because of the `testExample` test. Let's create a useful test:

```Swift
import XCTest
@testable import CommonMark

final class CommonMarkTests: XCTestCase {
    func testCaption() {
        let markdown = "# Caption"
        let node = Node(markdown: markdown)!
        let heading = node.children.first
        XCTAssertEqual(heading?.typeString, "heading")
    }
}
```

## Include the library with your app

If you want to include the `dylib ` with your app bundle you can create a `Frameworks` subdirectory below `Contents` and copy the library there. You can tell your app where it can find the library with the following command:

```bash
install_name_tool -change /usr/local/opt/cmark/lib/libcmark.0.29.0.dylib "@executable_path/../Frameworks/libcmark.dylib" ./<YourApp>.app/Contents/MacOS/Scratched
```

You can find out the the standard path of the library with the following command:

```bash
otool -L /usr/local/lib/libcmark.dylib
```