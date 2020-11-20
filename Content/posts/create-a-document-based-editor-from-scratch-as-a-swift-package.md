---
date: 2020-11-19 9:41
title: Create a document based editor from scratch as a swift package
description: How to create document based editor without Xcode templates, Storyboards and XIBs
tags: macOS, AppKit, KeyPath, CocoaBindings, SwiftPM
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---
I thought I had most of the information for this ready from either [Derik Ramirez's](https://rderik.com/blog/understanding-a-few-concepts-of-macos-applications-by-building-an-agent-based-menu-bar-app/) great blog or the great article [Creating macOS apps without a storyboard or .xib file with Swift 5](https://medium.com/@theboi/creating-macos-apps-without-a-storyboard-or-xib-file-516115ee9d26) from Ryan Theodore The. But I ran into some real hard to figure out pices that where all answered by the great guys from [objc.io](https://www.objc.io) — I am a happy subscriber 😀

## Create a Hello World App

```bash
mkdir ~/Desktop/Scratched
cd ~/Desktop/Scratched
swift package init --type executable
xed .
```

### Create an AppDelegate

```Swift
import Cocoa
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log(.debug, "%@ started", ProcessInfo.processInfo.processName as CVarArg)
    }
}
```

Remeber to set the target platform in Package.swift for this to work.

```Swift
let package = Package(
    name: "Scratched",
    platforms: [
        .macOS("11")
    ],...
```

### Update the main.swift file

```Swift
import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

Now you can press cmd-r and you should see the log message.

## Make it document based

### Create a model class
Let's reuse the same class I used [here](https://oliver-epper.de/posts/create-a-document-based-editor-with-xib-files-and-swifty-cocoa-bindings/)

```Swift
import Foundation

class Content: NSObject {
    @objc dynamic var contentString: String

    init(contentString: String) {
        self.contentString = contentString
    }
}

extension Content {
    func read(from data: Data) {
        contentString = String(bytes: data, encoding: .utf8) ?? ""
    }

    func data() -> Data {
        contentString.data(using: .utf8) ?? Data()
    }
}
```

Before we create the Document type let's create a ViewController.

### Create a ViewController

```Swift
import Cocoa
import os.log

final class ViewController: NSViewController {
    var textView = NSTextView()

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true

        textView.isRichText = false
        textView.allowsUndo = true
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView

        self.view = scrollView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let content = representedObject as? Content {
            textView.bind(.value, to: content, keyPath: \.contentString, options: [NSBindingOption.continuouslyUpdatesValue: true])
        }
    }
}

extension NSObject {
    func bind<Root, Value>(_ binding: NSBindingName, to observable: Root, keyPath: KeyPath<Root, Value>, options: [NSBindingOption: Any]? = nil) {
        guard let kvcKeyPath = keyPath._kvcKeyPathString else {
            os_log("KeyPath does not contain @objc exposed values")
            return
        }
        bind(binding, to: observable, withKeyPath: kvcKeyPath, options: options)
    }
}
```

### Create the document class

```Swift
import Cocoa

class Document: NSDocument {
    @objc dynamic var content = Content(contentString: "")

    private lazy var viewController = ViewController()

    override func makeWindowControllers() {
        viewController.representedObject = content
        let window = NSWindow(contentViewController: viewController)
        window.setContentSize(NSSize(width: 640, height: 480))
        let wc = NSWindowController(window: window)
        addWindowController(wc)
        wc.contentViewController = viewController
        window.setFrameAutosaveName("window_frame")
        window.makeKeyAndOrderFront(nil)
    }
}
```

### Create the document controller class

This is important to tell the system about our Document class. I learned this from [objc.io](https://www.objc.io).

```Swift
import Cocoa

class DocumentController: NSDocumentController {
    override var documentClassNames: [String] {
        ["Document"]
    }

    override var defaultType: String? {
        "Document"
    }

    override func documentClass(forType typeName: String) -> AnyClass? {
        Document.self
    }
}
```

**Now comes the fun part!**

To actually hook this up we need to add the following to the AppDelegate:

```Swift
func applicationWillFinishLaunching(_ notification: Notification) {
  _ = DocumentController()
}
```

Please take note that this is not `...DidFinish`, but `...WillFinish`! As Florian from [objc.io](https://www.objc.io) pointed out: **The first instance of a NSDocumentController in your app becomes the document controller of your app!**

And one more thing:

Normally you would have an entry like this in your Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

This tells the system that your app is a regular app. In code we add this to the main.swift:

```Swift
app.setActivationPolicy(.regular)
```

add it before the call to `run()`.

You should be able to start the app and type into the NSTextView, now.

### Let's create the menu

I initially found this in Ryan's article:

```Swift
import Cocoa

class Menu: NSMenu {
    private lazy var appName = ProcessInfo.processInfo.processName

    override init(title: String) {
        super.init(title: title)

        // App Menu
        let appMenu = NSMenuItem()
        appMenu.submenu = NSMenu()
        appMenu.submenu?.items = [
            NSMenuItem(title: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""),
            NSMenuItem.separator(),
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        ]
        
        // File Menu
        let fileMenu = NSMenuItem()
        fileMenu.submenu = NSMenu(title: "File")
        fileMenu.submenu?.items = [
            NSMenuItem(title: "New", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n"),
            NSMenuItem(title: "Open", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o"),
            NSMenuItem.separator(),
            NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"),
            NSMenuItem(title: "Save", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        ]

        // Edit Menu
        let editMenu = NSMenuItem()
        editMenu.submenu = NSMenu(title: "Edit")
        editMenu.submenu?.items = [
            NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"),
            NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        ]

        items = [appMenu, fileMenu, editMenu]
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
}
```

to hook it up edit main.swift:

```Swift
let menu = Menu()
app.menu = menu
```

### Enable open and save

add this to Document.swift:

```swift
override func data(ofType typeName: String) throws -> Data {
  viewController.textView.breakUndoCoalescing()
	return content.data()
}

override func read(from data: Data, ofType typeName: String) throws {
	content.read(from: data)
}
```

and these to tell the system that we handle normal text-files:

```Swift
override class var readableTypes: [String] {
  ["public.text"]
}

override class func isNativeType(_ type: String) -> Bool {
  true
}
```

### Magic sauce!

At this point you cannot select standard text files to open 😳 The Document class clearly says that is is able to read "public.text". But we need to make the complete class visible to the Objc runtime.

```Swift
@objc(Document)
class Documnt: NSDocument {...}
```

Thanks to the guys at [objc.io](https://www.objc.io) we now have a working text editor.

### Makefile

[Derik Ramirez](https://rderik.com) provided me with a simple Makefile:

```makefile
SUPPORTFILES=./SupportFiles
PLATFORM=x86_64-apple-macosx
BUILD_DIRECTORY = ./.build/${PLATFORM}/debug
APP_DIRECTORY=./Scratched.app
CFBUNDLEEXECUTABLE=Scratched

install: build copySupportFiles

build:
	swift build

copySupportFiles:
	mkdir -p ${APP_DIRECTORY}/Contents/MacOS/ && \
	cp ${SUPPORTFILES}/Info.plist ${APP_DIRECTORY}/Contents && \
	cp ${BUILD_DIRECTORY}/${CFBUNDLEEXECUTABLE} ${APP_DIRECTORY}/Contents/MacOS/

run: | install
	open ${APP_DIRECTORY}

clean:
	rm -rf .build
	rm -rf ${APP_DIRECTORY}

.PHONY: run build copySupportFiles clean
```

For this to work you need to create

```bash
mkdir SupportFiles
touch SupportFiles/Info.plist
```

And add the following content:

```XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict />
</plist>
```

Now you can run the app via

```bash
make run
```

