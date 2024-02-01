---
date: 2023-10-06 9:41
title: Autostart in macOS
description: The modern way
tags: macOS, autostart, ServiceManagement
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

## Registering your app as a LoginItem

If you search on how to register your app programmatically as a LoginItem you find a plethora of outdated information. So I thought it might be helpful to share this.

Basically you can register your app through `SMAppService.mainApp.register()` and unregister it with `SMAppService.mainApp.unregister()`. Checking what is currently configured is possible through `SMAppService.mainApp.status`. The thing that bugged me is: I found no way to get a notification of some kind if someone deletes your app from the LoginItems via the Settings app. I tried KVO without success. Thanks [Dave](https://davedelong.com) for confirming.

Say you want to show a toggle for the autostart feature in your app that might easily get out of sync with what is really configured in your system (if the LoginItem gets deleted via the Settings app). So we need to work around that.

The best idea so far is to re-check the current state when the mouse re-enters our window. Thanks [Kilian](https://kilian.io) for the idea!

## Autostart Model
```Swift
import Combine
import ServiceManagement

extension String: LocalizedError {
    public var errorDescription: String? {
        return self
    }
}

final class Autostart: ObservableObject {
    enum State: Equatable {
        case unknown
        case pending
        case autostart(Bool)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown), (.pending, .pending):
                return true
            case let (.autostart(lhsValue), .autostart(rhsValue)):
                return lhsValue == rhsValue
            default:
                return false
            }
        }
    }

    @Published var hasAutostart: State = .unknown
    private var cancellables = Set<AnyCancellable>()

    init(useTimer: Bool = false) {
        check()
        if useTimer {
            Timer.publish(every: 1.0, on: .current, in: .common).autoconnect().sink { [weak self] _ in
                self?.check()
            }.store(in: &cancellables)
        }
    }

    func check() {
        hasAutostart = .autostart(SMAppService.mainApp.status == .enabled)
    }

    func request(autostart: Bool) throws {
        hasAutostart = .pending
        if autostart {
#if DEBUG
            if Bool.random() {
                throw "Your random error that no one saw comming..."
            }
#endif
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        hasAutostart = .autostart(autostart)
    }
}
```

## A simple view
```
import SwiftUI

struct ContentView: View {
    @StateObject var autostart = Autostart(useTimer: true)
    @State private var errorMsg: String?

    var body: some View {
        let projection = Binding<Bool> {
            if case let .autostart(value) = autostart.hasAutostart {
                return value
            }
            return false
        } set: { wantsAutostart in
            do {
                try autostart.request(autostart: wantsAutostart)
                errorMsg = nil
            } catch {
                errorMsg = error.localizedDescription
            }
        }

        return ZStack {
            Color.clear.onHover { _ in
                autostart.check()
            }
            VStack {
                if let errorMsg {
                    Text(verbatim: errorMsg).foregroundStyle(.red)
                }
                Toggle(isOn: projection) {
                    Text(verbatim: "wants Autostart")
                }
                .toggleStyle(SwitchToggleStyle())
            }
        }
    }
}
```
