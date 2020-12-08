---
date: 2020-12-07 9:41
title: Wrap NSTextView in SwiftUI
description: How to wrap a NSTextView in SwiftUI
tags: macOS, AppKit, NSTextView, SwiftUI
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---
During WWDC 2020 SwiftUI lerned a few new things. For example Map and TextEditor. Both are neat additions but still not capable of replacing their corresponding AppKit or UIKit counterparts. The SwiftUI Map can handle annotations but not overlays, yet. And the TextEditor cannot present NSAttributedStrings. So let's wrap a NSTextView in SwiftUI and handle the updating of the model data in an efficient way.

## Create a ViewController that presents the NSTextView

This is pretty easy and no different than you'd expect:

```Swift
class EditorController: NSViewController {
    var textView = NSTextView()
    
    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 16)
        scrollView.documentView = textView
        
        self.view = scrollView
    }
    
    override func viewDidAppear() {
        self.view.window?.makeFirstResponder(self.view)
    }
}
```

In `viewDidAppear()` I make the controllers view the first responder. I like to be able to start typing immmediatly when the view get's presented and not have to click with the mouse, first. 😎



## Create a Representable

To wrap a `NSViewController` inside a SwiftUI View struct you can use the protocol `NSViewControllerRepresentable`:

```Swift
struct EditorControllerView: NSViewControllerRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextStorageDelegate {
        private var parent: EditorControllerView
        var shouldUpdateText = true
        
        init(_ parent: EditorControllerView) {
            self.parent = parent
        }
        
        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard shouldUpdateText else {
                return
            }
            let edited = textStorage.attributedSubstring(from: editedRange).string
            let insertIndex = parent.text.utf16.index(parent.text.utf16.startIndex, offsetBy: editedRange.lowerBound)
            
            func numberOfCharactersToDelete() -> Int {
                editedRange.length - delta
            }
            
            let endIndex = parent.text.utf16.index(insertIndex, offsetBy: numberOfCharactersToDelete())
            self.parent.text.replaceSubrange(insertIndex..<endIndex, with: edited)
        }
    }

    func makeNSViewController(context: Context) -> EditorController {
        let vc = EditorController()
        vc.textView.textStorage?.delegate = context.coordinator
        return vc
    }
    
    func updateNSViewController(_ nsViewController: EditorController, context: Context) {
        if text != nsViewController.textView.string {
            context.coordinator.shouldUpdateText = false
            nsViewController.textView.string = text
            context.coordinator.shouldUpdateText = true
        }
    }
}
```

The basic idea is to use a `NSTextStorageDelegate`  to apply the edit that was done to the `textView.textStorage` to the `@Binding`-property.

But there's a bit to consider:

- Once the `@Binding` property got updated it will call the `updateNSViewController` function. This only needs to really do anything if the change originated from the SwiftUI-side of things. If the change came from the ViewController there is nothing more to do.

- The internal representation of the string in the `NSTextStorage` is utf-16. So if you enter a 😎 in the `textView` the `textStorage`-delegate function will tell you that you edited from 0 to 2 and inserted 2 characters. If you replace the 😎 with a 👨‍👩‍👧‍👧 you will edit from 0 to 11 with a delta of 9. Easy 😬

- So the function gets the string representing the editedRange from the `textStorage` and calculates the position to insert from the utf16-representation. If you replace the 👨‍👩‍👧‍👧 with a 😎 again you edited from 0 to 2 with a delta of -9. This means: for your one character long string to remain one character long you need to delete 9 characters from 2 to 11. ❤️

Since every update has to change the `@Binding` property we do both in one go with the handy `replaceSubrange` function.



## Testdrive

Yeah! Now we have a nice SwiftUI component:

```Swift
struct ContentView: View {
    @State private var text = ""
    
    var body: some View {
        VStack(alignment: .trailing) {
            HStack {
                Text("count_key")
                Text(String(text.count))
            }.padding()
            EditorControllerView(text: $text) // our component
            TextEditor(text: $text) // SwiftUI
        }
    }
}
```

Try profiling this against the naive approach of just setting the text property on every update and you'll see how much faster this approach is.

Try editing in a long text > 4Mb with and without the SwiftUI `TextEditor`.

